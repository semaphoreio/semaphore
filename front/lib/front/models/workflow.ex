defmodule Front.Models.Workflow do
  require Logger

  @type t :: %__MODULE__{
          id: String.t()
        }

  alias Front.Clients

  alias InternalApi.PlumberWF.{
    DescribeManyRequest,
    DescribeRequest,
    GitRefType,
    ListKeysetRequest,
    ListLatestWorkflowsRequest,
    ListRequest,
    TriggeredBy
  }

  alias InternalApi.Velocity.ListPipelineSummariesRequest

  alias Google.Rpc.Code

  defstruct [
    :id,
    :project_name,
    :author_avatar_url,
    :author_name,
    :short_commit_id,
    :github_commit_url,
    :commit_message,
    :branch_id,
    :branch_name,
    :project_id,
    :root_pipeline_id,
    :hook_id,
    :requester_id,
    :requester,
    :hook,
    :pipelines,
    :created_at,
    :git_ref_type,
    :commit_sha,
    :triggered_by,
    :rerun_of,
    :summary
  ]

  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])

  def find_latest(project_id: project_id, branch_name: branch_name) do
    request =
      ListRequest.new(
        project_id: project_id,
        label: branch_name,
        git_ref_types: [GitRefType.value(:BRANCH)],
        page_size: 1,
        page: 1
      )

    {:ok, response} = Clients.Workflow.list(request)

    case response.workflows |> List.first() do
      nil -> nil
      workflow -> construct(workflow)
    end
  end

  def find_latest(project_id: project_id, branch_name: branch_name, commit_sha: commit_sha) do
    request =
      ListRequest.new(
        project_id: project_id,
        branch_name: branch_name,
        page_size: 10,
        page: 1
      )

    {:ok, response} = Clients.Workflow.list(request)

    cond do
      response.workflows == [] ->
        # there are no workflows on the branch
        nil

      is_nil(commit_sha) || Enum.member?([:dev, :test], Application.get_env(:front, :environment)) ->
        # we didn't pass a concrete commit_id, any workflow will do
        construct(List.first(response.workflows))

      true ->
        # there are multiple workflows on the branch, and the client passed
        # an explicit commit id. Time to search through the collection.

        wf = Enum.find(response.workflows, fn w -> w.commit_sha == commit_sha end)

        if wf do
          construct(wf)
        else
          nil
        end
    end
  end

  @find_cache_prefix "workflow-model-find-v1"
  @find_cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()
  def find(id) do
    cache_key = "#{@find_cache_prefix}/#{@find_cache_version}/#{id}"

    if Cacheman.exists?(:front, cache_key) do
      {:ok, cache} = Cacheman.get(:front, cache_key)
      cache |> decode()
    else
      case find(id, :from_api) do
        nil ->
          nil

        response ->
          ttl = get_ttl_for_workflow(response)
          Cacheman.put(:front, cache_key, encode(response), ttl: ttl)
          response
      end
    end
  end

  def find_many(ids) do
    {cached_ids, non_cached_ids} =
      Enum.split_with(ids, fn id ->
        Cacheman.exists?(:front, workflow_cache_key(id))
      end)

    cached_workflows =
      cached_ids
      |> Enum.map(fn id ->
        {:ok, cache} = Cacheman.get(:front, workflow_cache_key(id))
        cache |> decode()
      end)

    non_cached_workflows = find_many(non_cached_ids, :from_api)

    Enum.each(non_cached_workflows, fn workflow ->
      ttl = get_ttl_for_workflow(workflow)
      Cacheman.put(:front, workflow_cache_key(workflow.id), encode(workflow), ttl: ttl)
    end)

    cached_workflows ++ non_cached_workflows
  end

  defp workflow_cache_key(id), do: "#{@find_cache_prefix}/#{@find_cache_version}/#{id}"

  def find_many_by_ids(ids) do
    ids |> Enum.map(fn id -> find(id) end)
  end

  def invalidate(id) do
    "#{@find_cache_prefix}/#{@find_cache_version}/#{id}"
    |> then(&Cacheman.delete(:front, &1))
  end

  def find(id, :from_api) do
    {:ok, response} = Clients.Workflow.describe(%DescribeRequest{wf_id: id})

    case Code.key(response.status.code) do
      :OK -> construct(response.workflow)
      :FAILED_PRECONDITION -> nil
      :NOT_FOUND -> nil
    end
  end

  def find(id, _tracing_headers), do: find(id)

  def find_many(ids, :from_api) do
    {:ok, response} = Clients.Workflow.describe_many(%DescribeManyRequest{wf_ids: ids})

    case Code.key(response.status.code) do
      :OK -> construct(response.workflows)
      :FAILED_PRECONDITION -> []
      :NOT_FOUND -> []
    end
  end

  def find_many(ids, _tracing_headers), do: find_many(ids)

  def list(params \\ [], options \\ [], tracing_headers \\ nil) do
    defaults = [
      page: 1,
      page_size: 100
    ]

    req = defaults |> Keyword.merge(params) |> ListRequest.new()

    case pagination(options) do
      nil -> request_stream(req, tracing_headers, :one_page)
      :one_page -> request_stream(req, tracing_headers, :one_page)
      :auto -> request_stream(req, tracing_headers)
      :manual -> request(req, tracing_headers)
    end
  end

  defp ref_types(names) do
    names
    |> Enum.filter(fn x -> x != "" end)
    |> Enum.map(&String.upcase/1)
    |> Enum.map(&String.to_atom/1)
    |> Enum.map(&InternalApi.PlumberWF.GitRefType.value/1)
  end

  defp direction("next"),
    do: InternalApi.PlumberWF.ListLatestWorkflowsRequest.Direction.value(:NEXT)

  defp direction("previous"),
    do: InternalApi.PlumberWF.ListLatestWorkflowsRequest.Direction.value(:PREVIOUS)

  defp direction(_),
    do: InternalApi.PlumberWF.ListLatestWorkflowsRequest.Direction.value(:NEXT)

  def list_keyset(params \\ []) do
    defaults = [
      page_size: 20,
      page_token: ""
    ]

    ref_types = ref_types(params[:git_ref_types] || [])

    req =
      defaults
      |> Keyword.merge(params)
      |> Keyword.merge(git_ref_types: ref_types)
      |> ListKeysetRequest.new()

    {:ok, response} = Clients.Workflow.list_keyset(req)

    case Code.key(response.status.code) do
      :OK ->
        {construct(response.workflows), response.next_page_token, response.previous_page_token}

      _ ->
        response
    end
  end

  def list_latest_workflows(params \\ []) do
    defaults = [
      page_size: 10,
      page_token: ""
    ]

    ref_types = ref_types(params[:git_ref_types] || [])
    direction = direction(params[:direction] || "next")

    req =
      defaults
      |> Keyword.merge(params)
      |> Keyword.merge(git_ref_types: ref_types, direction: direction)
      |> ListLatestWorkflowsRequest.new()

    {:ok, response} = Clients.Workflow.list_latest_workflows(req)
    {construct(response.workflows), response.next_page_token, response.previous_page_token}
  end

  defp request_stream(req, tracing_headers, override \\ nil) do
    request(req, tracing_headers) |> stream_if_needed(override)
  end

  defp request(req, _tracing_headers) do
    {:ok, response} = Clients.Workflow.list(req)

    case Code.key(response.status.code) do
      :OK -> {:ok, construct(response.workflows), page(response), next_page(response), req}
      :BAD_PARAM -> {:error, nil, nil, nil, req}
    end
  end

  @spec pagination(keyword) :: atom | nil
  defp pagination(options) do
    Keyword.get(options, :pagination, :one_page)
  end

  def next_page(resp) do
    if resp.page_number == resp.total_pages do
      nil
    else
      resp.page_number + 1
    end
  end

  def page(resp) do
    %{
      page_size: resp.page_size,
      current_page: resp.page_number,
      next_page: resp.page_number + 1,
      total_entries: resp.total_entries,
      total_pages: resp.total_pages
    }
  end

  def empty_page do
    %{
      page_size: 0,
      current_page: 0,
      next_page: 0,
      total_entries: 0,
      total_pages: 0
    }
  end

  defp stream_if_needed({_, response, _, _, _}, :one_page), do: response
  defp stream_if_needed({_, response, _, nil, _}, _), do: response

  defp stream_if_needed(initial_results, nil) do
    Enum.to_list(Stream.resource(fn -> initial_results end, &process_stream/1, fn _ -> nil end))
  end

  defp process_stream({_, [], _, nil, _}), do: {:halt, nil}

  defp process_stream({_, [], _, next_page, req}) do
    req = %{req | page: next_page}

    request(req, nil)
    |> process_stream
  end

  defp process_stream({_, items, page, next_page, req}) when is_list(items) do
    {items, {:ok, [], page, next_page, req}}
  end

  defp process_stream({_, item, page, next_page, req}) do
    {[item], {:ok, [], page, next_page, req}}
  end

  def construct(workflows) when is_list(workflows) do
    workflows
    |> Enum.map(fn workflow -> construct(workflow, preload: false) end)
    |> preload_project_name()
    |> preload_requester()
    |> preload_commit_data()
    |> preload_pipelines()
    |> preload_summary()
  end

  def construct(workflow, opts \\ []) do
    preload? = Keyword.get(opts, :preload, true)

    %__MODULE__{
      id: workflow.wf_id,
      short_commit_id: workflow.commit_sha |> String.slice(0..6),
      commit_sha: workflow.commit_sha,
      branch_id: workflow.branch_id,
      branch_name: workflow.branch_name,
      project_id: workflow.project_id,
      root_pipeline_id: workflow.initial_ppl_id,
      hook_id: workflow.hook_id,
      requester_id: workflow.requester_id,
      created_at: DateTime.from_unix!(workflow.created_at.seconds),
      triggered_by: TriggeredBy.key(workflow.triggered_by),
      rerun_of: workflow.rerun_of
    }
    |> then(fn
      workflow when preload? ->
        workflow
        |> preload_project_name()
        |> preload_requester()
        |> preload_commit_data()
        |> preload_pipelines()
        |> preload_summary()

      workflow ->
        workflow
    end)
  end

  def preload_requester(workflows) when is_list(workflows) do
    requester_ids =
      workflows
      |> Enum.filter(fn workflow ->
        workflow.requester == nil and workflow.requester_id != ""
      end)
      |> Enum.map(& &1.requester_id)

    Front.Models.User.find_many(requester_ids)
    |> then(fn requesters ->
      workflows
      |> Enum.map(fn workflow ->
        requesters
        |> Enum.find(&(&1.id == workflow.requester_id))
        |> then(fn
          nil ->
            workflow

          requester ->
            %{workflow | requester: requester}
        end)
      end)
    end)
  end

  def preload_requester(workflow) do
    [workflow] = preload_requester([workflow])

    workflow
  end

  def preload_commit_data(workflows) when is_list(workflows) do
    hook_ids =
      workflows
      |> Enum.filter(fn workflow ->
        workflow.hook == nil and workflow.hook_id != "" and workflow.hook_id != nil
      end)
      |> Enum.map(& &1.hook_id)

    Front.Models.RepoProxy.find(hook_ids)
    |> case do
      hooks ->
        workflows
        |> Enum.map(fn workflow ->
          hooks
          |> Enum.find(&(&1.id == workflow.hook_id))
          |> then(fn
            nil ->
              workflow

            hook ->
              %{workflow | hook: hook}
          end)
        end)
    end
  end

  def preload_commit_data(workflow) do
    [workflow] = preload_commit_data([workflow])

    workflow
  end

  def preload_pipelines(workflows) when is_list(workflows) do
    Front.Utils.parallel_map(workflows, fn workflow ->
      options = [pagination: :auto]
      pipelines = Front.Models.Pipeline.list([wf_id: workflow.id], options)

      %{workflow | pipelines: pipelines}
    end)
  end

  def preload_pipelines(workflow) do
    [workflow] = preload_pipelines([workflow])

    workflow
  end

  def preload_summary(workflows) when is_list(workflows) do
    pipeline_ids =
      workflows
      |> Enum.flat_map(fn workflow ->
        workflow.pipelines
        |> Enum.filter(fn pipeline ->
          pipeline.summary == nil
        end)
        |> Enum.map(& &1.id)
      end)

    ListPipelineSummariesRequest.new(pipeline_ids: pipeline_ids)
    |> Clients.Velocity.list_pipeline_summaries()
    |> case do
      {:ok, %{pipeline_summaries: pipeline_summaries}} -> pipeline_summaries
      _ -> []
    end
    |> then(fn pipeline_summaries ->
      workflows
      |> Enum.map(fn workflow ->
        pipelines =
          workflow.pipelines
          |> Enum.map(fn pipeline ->
            summary =
              Enum.find(pipeline_summaries, &(&1.pipeline_id == pipeline.id))
              |> Front.Models.TestSummary.load()

            %{pipeline | summary: summary}
          end)

        workflow_summary =
          Enum.find(pipelines, &(&1.id == workflow.root_pipeline_id))
          |> case do
            nil ->
              nil

            %{summary: workflow_summary} ->
              workflow_summary
              |> Front.Models.TestSummary.load()
          end

        %{workflow | pipelines: pipelines, summary: workflow_summary}
      end)
    end)
  end

  def preload_summary(workflow) do
    [workflow] = preload_summary([workflow])

    workflow
  end

  def preload_project_name(workflows) when is_list(workflows) do
    workflows
    |> Enum.filter(&(&1.project_name == "" or is_nil(&1.project_name)))
    |> Enum.map(& &1.project_id)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> Front.Models.Project.project_names()
    |> then(fn project_names ->
      workflows
      |> Enum.map(fn %{project_id: project_id} = workflow ->
        project_name =
          Enum.find(project_names, fn
            {^project_id, _} -> true
            _ -> false
          end)
          |> case do
            nil -> ""
            {_, project_name} -> project_name
          end

        %{workflow | project_name: project_name}
      end)
    end)
  end

  def preload_project_name(workflow) do
    [workflow] = preload_project_name([workflow])

    workflow
  end

  defp has_active_pipelines?(workflow) do
    workflow.pipelines
    |> Enum.any?(fn pipeline ->
      pipeline.state in [:RUNNING, :STOPPING, :PENDING, :QUEUING, :INITIALIZING]
    end)
  end

  defp get_ttl_for_workflow(workflow) do
    if has_active_pipelines?(workflow) do
      # Finite cache for workflows with active pipelines
      :timer.hours(2)
    else
      # Never expire for completed workflows
      :infinity
    end
  end
end
