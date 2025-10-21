defmodule Front.ProjectPage.Model do
  use TypedStruct
  alias Front.{Async, Decorators, Models}
  alias InternalApi.PlumberWF.ListKeysetRequest.Direction, as: KeysetDirection
  require Logger

  typedstruct do
    field(:project, Front.Model.Project.t())
    field(:page_token, String.t())
    field(:direction, String.t())
    field(:list_mode, String.t())
    field(:user_page?, boolean())
    field(:ref_types, String.t())
    field(:workflows, [Front.Model.Workflow.t()], enforce: true)
    field(:branches, [Front.Model.Branch.t()])
    field(:organization, Front.Model.Organization.t())
    field(:pagination, Front.ProjectPage.Model.Pagination.t())
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
      field(:project_id, String.t(), enforce: true)
      field(:organization_id, String.t(), enforce: true)
      field(:user_id, String.t())
      field(:page_token, String.t(), default: "")
      field(:direction, String.t())
      field(:list_mode, String.t(), default: "latest")
      field(:user_page?, boolean())
      field(:ref_types, [String.t()])
    end
  end

  @cache_prefix "project_page_model"
  @cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  # Used to update the model cache version, when there is no change in the model file
  # @cache_hidden_version = "2"

  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])

  @spec get(LoadParams.t()) :: {:ok, __MODULE__.t()} | {:error, String.t()}
  def get(params, opts \\ []) do
    with true <- first_page?(params),
         true <- everyones_page?(params),
         true <- cacheable_mode?(params) do
      fetch_from_cache(params, opts[:force_cold_boot])
    else
      false ->
        load_from_api(params)
    end
  end

  defp fetch_from_cache(params, force_cold_boot?) do
    if force_cold_boot? do
      refresh(params)
    else
      case Cacheman.get(:front, cache_key(params)) do
        {:ok, nil} ->
          Watchman.increment({"project_page_model.cache.miss", []})
          refresh(params)

        {:ok, val} ->
          Watchman.increment({"project_page_model.cache.hit", []})
          {:ok, decode(val), :from_cache}

        e ->
          e
      end
    end
  end

  def cache_key(params) do
    "#{cache_prefix()}/#{cache_version()}/project_id=#{params.project_id}/ref_types=#{params.ref_types}/list_mode=#{params.list_mode}/"
  end

  @spec refresh(LoadParams.t()) :: {:ok, t(), atom()} | {:error, String.t()}
  def refresh(params) do
    params |> invalidate()

    load_from_api(params)
    |> case do
      {:ok, data, _} ->
        Cacheman.put(:front, cache_key(params), encode(data))

        {:ok, data, :from_api}

      _ ->
        {:error, "Can't refresh the ProjectPage model"}
    end
  end

  @spec invalidate(LoadParams.t()) :: {:ok, String.t()} | {:error, String.t()}
  def invalidate(params) do
    case Cacheman.delete(:front, params |> cache_key()) do
      {:ok, 1} ->
        Logger.info("[PROJECT PAGE MODEL] Removed cache key #{params |> cache_key()}")
        {:ok, 1}

      {:ok, 0} ->
        Logger.info("[PROJECT PAGE MODEL] Cache key not found #{params |> cache_key()}")
        {:ok, 0}

      e ->
        e
    end
  end

  @spec load_from_api(LoadParams.t()) :: {:ok, t(), atom()} | {:error, String.t()}
  def load_from_api(params) do
    Watchman.benchmark("project_page_model_load_from_api", fn ->
      fetch_workflows =
        Async.run(fn ->
          metric_name =
            if params.user_page? do
              "project_page_model_list_workflows_by_me"
            else
              "project_page_model_list_workflows"
            end

          Watchman.benchmark(metric_name, fn ->
            list_workflows(params)
          end)
        end)

      fetch_organization =
        Async.run(fn ->
          Watchman.benchmark("project_page_model_find_organization", fn ->
            Models.Organization.find(params.organization_id)
          end)
        end)

      fetch_project =
        Async.run(fn ->
          Watchman.benchmark("project_page_model_find_project", fn ->
            Models.Project.find_by_id(params.project_id, params.organization_id)
          end)
        end)

      {:ok, {workflows, next_page_token, previous_page_token}} = Async.await(fetch_workflows)
      {:ok, organization} = Async.await(fetch_organization)
      {:ok, project} = Async.await(fetch_project)

      previous = if previous_page_token != "", do: previous_page_token, else: nil
      next = if next_page_token != "", do: next_page_token, else: nil
      newest = if params.page_token == "", do: false, else: true
      visible = if previous != nil or next != nil, do: true, else: false

      pagination =
        struct!(__MODULE__.Pagination,
          previous: previous,
          next: next,
          newest: newest,
          visible: visible
        )

      model =
        struct!(__MODULE__,
          project: project,
          page_token: params.page_token,
          direction: params.direction,
          list_mode: params.list_mode,
          user_page?: params.user_page?,
          ref_types: params.ref_types,
          workflows: workflows,
          branches: [],
          organization: organization,
          pagination: pagination
        )

      {:ok, model, :from_api}
    end)
  end

  def cache_prefix, do: @cache_prefix
  def cache_version, do: @cache_version

  ## Private

  defp first_page?(params), do: params.page_token == ""
  defp everyones_page?(params), do: params.user_page? == false
  defp cacheable_mode?(params), do: (params.list_mode || "latest") == "latest"

  defp list_workflows(params) do
    case params.list_mode do
      "all_pipelines" -> list_workflows_keyset(params)
      _ -> list_workflows_latest(params)
    end
  end

  defp list_workflows_latest(params) do
    list_params = [
      page_size: 10,
      page_token: params.page_token,
      direction: params.direction,
      project_id: params.project_id,
      git_ref_types: params.ref_types
    ]

    list_params = maybe_put_requester(list_params, params.user_page?, params.user_id)

    workflow_api_metric_name =
      if params.user_page? do
        "project_page_model_list_latest_workflows_by_me"
      else
        "project_page_model_list_latest_workflows"
      end

    {wfs, next_page_token, previous_page_token} =
      Watchman.benchmark(workflow_api_metric_name, fn ->
        Models.Workflow.list_latest_workflows(list_params)
      end)

    workflows =
      Watchman.benchmark("project_page_model_decorate_workflows", fn ->
        Decorators.Workflow.decorate_many(wfs)
      end)

    {workflows, next_page_token, previous_page_token}
  end

  defp list_workflows_keyset(params) do
    direction = keyset_direction(params.direction)

    list_params =
      [
        page_size: 10,
        page_token: params.page_token,
        direction: direction,
        project_id: params.project_id,
        git_ref_types: params.ref_types
      ]
      |> maybe_put_requester(params.user_page?, params.user_id)
      |> Enum.reject(fn {_, value} -> is_nil(value) or value == "" end)

    workflow_api_metric_name =
      if params.user_page? do
        "project_page_model_list_keyset_by_me"
      else
        "project_page_model_list_keyset"
      end

    {wfs, next_page_token, previous_page_token} =
      Watchman.benchmark(workflow_api_metric_name, fn ->
        Models.Workflow.list_keyset(list_params)
      end)

    workflows =
      Watchman.benchmark("project_page_model_decorate_workflows", fn ->
        Decorators.Workflow.decorate_many(wfs)
      end)

    {workflows, next_page_token, previous_page_token}
  end

  defp maybe_put_requester(list_params, true, requester_id),
    do: Keyword.merge(list_params, requester_id: requester_id)

  defp maybe_put_requester(list_params, _requester?, _requester_id), do: list_params

  defp keyset_direction("next"), do: KeysetDirection.value(:NEXT)
  defp keyset_direction("previous"), do: KeysetDirection.value(:PREVIOUS)
  defp keyset_direction(_), do: nil
end
