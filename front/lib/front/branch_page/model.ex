defmodule Front.BranchPage.Model do
  use TypedStruct

  alias Front.Async
  alias Front.Models

  alias InternalApi.PlumberWF.ListKeysetRequest.Direction

  require Logger

  typedstruct do
    field(:organization, Models.Organization.t())
    field(:workflows, [Models.Workflow.t()])
    field(:pagination, Front.BranchPage.Model.Pagination.t())
  end

  defmodule Pagination do
    use TypedStruct

    typedstruct do
      field(:visible, boolean())
      field(:newest, boolean())
      field(:next, String.t())
      field(:previous, String.t())
    end
  end

  defmodule LoadParams do
    use TypedStruct

    typedstruct do
      field(:branch_name, String.t())
      field(:branch_id, String.t())
      field(:project_id, String.t())
      field(:organization_id, String.t())
      field(:page_token, String.t())
      field(:direction, String.t())
      field(:date_from, String.t())
      field(:date_to, String.t())
      field(:author, String.t())
    end
  end

  @cache_prefix "branch_page_model"
  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  def cache_version, do: @cache_version

  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])

  @spec get(LoadParams.t()) :: {:ok, __MODULE__.t()} | {:error, String.t()}
  def get(params, opts \\ []) do
    case first_page?(params) do
      true -> fetch_from_cache(params, opts[:force_cold_boot])
      false -> load_from_api(params)
    end
  end

  defp fetch_from_cache(params, force_cold_boot?) do
    if force_cold_boot? do
      refresh(params)
    else
      case Cacheman.get(:front, cache_key(params)) do
        {:ok, nil} ->
          Watchman.increment({"branch_page_model.cache.miss", []})
          refresh(params)

        {:ok, val} ->
          Watchman.increment({"branch_page_model.cache.hit", []})
          {:ok, decode(val), :from_cache}

        e ->
          e
      end
    end
  end

  def cache_key(params) do
    "#{@cache_prefix}/#{@cache_version}/branch_id=#{params.branch_id}/"
  end

  @spec refresh(LoadParams.t()) :: {:ok, t(), atom()}
  def refresh(params) do
    params |> invalidate()

    {:ok, data, _} = load_from_api(params)
    Cacheman.put(:front, cache_key(params), encode(data))

    {:ok, data, :from_api}
  end

  @spec invalidate(LoadParams.t()) :: {:ok, String.t()} | {:error, String.t()}
  def invalidate(params) do
    case Cacheman.delete(:front, params |> cache_key()) do
      {:ok, 1} ->
        Logger.info("[BRANCH PAGE MODEL] Removed cache key #{params |> cache_key()}")
        {:ok, 1}

      {:ok, 0} ->
        Logger.info("[BRANCH PAGE MODEL] Cache key not found #{params |> cache_key()}")
        {:ok, 0}

      e ->
        e
    end
  end

  def load_from_api(params) do
    fetch_workflows = Async.run(fn -> list_workflows(params) end)

    fetch_organization = Async.run(fn -> Models.Organization.find(params.organization_id) end)

    {:ok, {workflows, next_page_token, previous_page_token}} = Async.await(fetch_workflows)
    {:ok, organization} = Async.await(fetch_organization)

    previous = if previous_page_token != "", do: previous_page_token, else: nil
    next = if next_page_token != "", do: next_page_token, else: nil
    newest = if params.page_token == "", do: false, else: true
    visible = if previous != nil or next != nil, do: true, else: false

    pagination =
      struct!(__MODULE__.Pagination,
        visible: visible,
        newest: newest,
        next: next,
        previous: previous
      )

    model =
      struct!(__MODULE__,
        organization: organization,
        workflows: workflows,
        pagination: pagination
      )

    {:ok, model, :from_api}
  end

  defp list_workflows(params) do
    api_params =
      [
        page_size: 10,
        page_token: params.page_token,
        project_id: params.project_id,
        branch_name: params.branch_name,
        direction: map_workflow_direction(params.direction)
      ]
      |> inject_date_filter_param(params.date_from, :date_from)
      |> inject_date_filter_param(params.date_to, :date_to)
      |> inject_requesters_param(params.author, params.organization_id, params.project_id)

    {wfs, next_page_token, previous_page_token} =
      api_params
      |> Models.Workflow.list_keyset()

    workflows = Front.Decorators.Workflow.decorate_many(wfs)

    {workflows, next_page_token, previous_page_token}
  end

  defp inject_requesters_param(api_params, author, _, _) when author in [nil, ""], do: api_params

  defp inject_requesters_param(api_params, author, org_id, project_id) do
    case Front.RBAC.Members.list_project_members(org_id, project_id, username: author) do
      {:ok, {members, _total_pages}} ->
        case members |> Enum.map(& &1.id) do
          [] -> api_params
          user_ids -> Keyword.put(api_params, :requester_ids, user_ids)
        end

      _ ->
        api_params
    end
  end

  defp inject_date_filter_param(api_params, date, _) when date in [nil, ""], do: api_params

  defp inject_date_filter_param(api_params, date, :date_from),
    do: Keyword.put(api_params, :created_after, timestamp(:beginning, date))

  defp inject_date_filter_param(api_params, date, :date_to),
    do: Keyword.put(api_params, :created_before, timestamp(:beginning, date))

  defp timestamp(_, timestamp) when timestamp in [nil, ""], do: nil

  @date_format "{YYYY}-{0M}-{0D}"
  defp timestamp(direction, date) do
    rounding_func =
      case direction do
        :beginning -> &Timex.beginning_of_day/1
        :end -> &Timex.end_of_day/1
        _ -> nil
      end

    case Timex.parse(date, @date_format) do
      {:ok, datetime} ->
        datetime |> Timex.to_datetime() |> rounding_func.() |> to_google_timestamp()

      {:error, reason} ->
        Logger.error("Error parsing date: #{inspect(reason)}")
        nil
    end
  end

  defp to_google_timestamp(date) do
    case Timex.to_unix(date) do
      {:error, _} -> nil
      s -> Google.Protobuf.Timestamp.new(seconds: s)
    end
  end

  defp map_workflow_direction("next"), do: Direction.value(:NEXT)
  defp map_workflow_direction("previous"), do: Direction.value(:PREVIOUS)
  defp map_workflow_direction(_), do: map_workflow_direction("next")

  defp first_page?(params) do
    filter_fields = [:page_token, :date_from, :date_to, :author]

    Enum.all?(filter_fields, fn field ->
      is_nil(Map.get(params, field)) || Map.get(params, field) == ""
    end)
  end
end
