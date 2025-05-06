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
    end
  end

  @cache_prefix "branch_page_model"
  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  def cache_version, do: @cache_version

  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])

  @spec get(LoadParams.t()) :: {:ok, __MODULE__.t()} | {:error, String.t()}
  def get(params, opts \\ []) do
    IO.puts("GET")
    with true <- first_page?(params) do
      IO.puts("FIRST PAGE")
      fetch_from_cache(params, opts[:force_cold_boot])
    else
      false ->
        IO.puts(" NOT FIRST PAGE")
        load_from_api(params)
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
    IO.puts("LOAD FROM API")
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
    {wfs, next_page_token, previous_page_token} =
      [
        page_size: 10,
        page_token: params.page_token,
        project_id: params.project_id,
        branch_name: params.branch_name,
        direction: map_workflow_direction(params.direction)
      ]
      |> Models.Workflow.list_keyset()

    workflows = Front.Decorators.Workflow.decorate_many(wfs)

    {workflows, next_page_token, previous_page_token}
  end

  defp map_workflow_direction("next"), do: Direction.value(:NEXT)
  defp map_workflow_direction("previous"), do: Direction.value(:PREVIOUS)
  defp map_workflow_direction(_), do: map_workflow_direction("next")

  defp first_page?(params), do: params.page_token == ""
end
