defmodule Front.Models.Pipeline do
  # The following functions are being cached:
  #
  # 2. __MODULE__.topology/1
  # 3. __MODULE__.find_metadata/1

  require Logger

  alias Front.Clients

  alias InternalApi.Plumber.{
    DescribeManyRequest,
    DescribeRequest,
    DescribeTopologyRequest,
    ListKeysetRequest,
    ListRequest,
    PartialRebuildRequest,
    Pipeline,
    TerminateRequest
  }

  alias Front.Models
  alias Front.WorkflowPage.Diagram
  alias InternalApi.Plumber.Block.Result, as: BlockResult
  alias InternalApi.Plumber.Block.ResultReason, as: BlockResultReason
  alias InternalApi.Plumber.Block.State, as: BlockState
  alias InternalApi.Plumber.Pipeline.Result, as: PipelineResult
  alias InternalApi.Plumber.Pipeline.ResultReason, as: PipelineResultReason
  alias InternalApi.Plumber.Pipeline.State, as: PipelineState
  alias InternalApi.Plumber.ResponseStatus.ResponseCode
  alias InternalApi.PlumberWF.GetPathRequest

  defmodule CompileTask do
    use TypedStruct

    typedstruct do
      field(:present?, Boolean.t())
      field(:task_id, String.t())
      field(:job_id, String.t())
      field(:job_log_path, String.t())
      field(:running?, Boolean.t())
      field(:failed?, Boolean.t())
      field(:done?, Boolean.t())
      field(:started_at, integer())
      field(:done_at, integer())
    end
  end

  defmodule AfterTask do
    use TypedStruct

    defmodule Job do
      use TypedStruct

      typedstruct do
        field(:id, String.t())
        field(:name, String.t())
        field(:running?, Boolean.t())
        field(:failed?, Boolean.t())
        field(:done?, Boolean.t())
        field(:started_at, integer())
        field(:done_at, integer())
      end
    end

    typedstruct do
      field(:present?, Boolean.t())
      field(:task_id, String.t())
      field(:jobs, [Job.t()])
    end

    def construct_from_topology(nil) do
      struct!(__MODULE__, jobs: [])
    end

    def construct_from_topology(%{jobs: jobs}) do
      jobs =
        Enum.map(jobs, fn job_name ->
          %{
            id: nil,
            name: job_name,
            state: :PENDING,
            started_at: nil,
            finished_at: nil
          }
        end)

      struct!(__MODULE__, jobs: jobs, present?: length(jobs) > 0)
    end
  end

  @type t :: %Front.Models.Pipeline{
          id: String.t(),
          organization_id: String.t(),
          name: String.t(),
          blocks: [Front.Models.Pipeline.Block.t()],
          state: PipelineState.t(),
          result: PipelineResult.t(),
          result_reason: PipelineResultReason.t(),
          timeline: %{
            created_at: integer(),
            pending_at: integer(),
            queuing_at: integer(),
            running_at: integer(),
            stopping_at: integer(),
            done_at: integer()
          },
          error_description: String.t(),
          pipeline_path: String.t(),
          yaml_file_name: String.t(),
          workflow_id: String.t(),
          project_id: String.t(),
          branch_id: String.t(),
          hook_id: String.t(),
          switch_id: String.t(),
          terminated_by: String.t(),
          terminator: Front.Models.User.t(),
          promotion_of: String.t(),
          partial_rerun_of: String.t(),
          compile_task: CompileTask.t(),
          after_task: AfterTask.t(),
          env_vars: [%{name: String.t(), value: String.t()}],
          triggerer: Models.Pipeline.Triggerer.t()
        }

  defstruct [
    :id,
    :organization_id,
    :name,
    :blocks,
    :state,
    :result,
    :result_reason,
    :timeline,
    :error_description,
    :pipeline_path,
    :yaml_file_name,
    :workflow_id,
    :project_id,
    :branch_id,
    :hook_id,
    :switch_id,
    :terminated_by,
    :terminator,
    :done_at,
    :promotion_of,
    :partial_rerun_of,
    :jobs_are_waiting?,
    :compile_task,
    :after_task,
    :summary,
    :env_vars,
    :triggerer
  ]

  @model_cache_prefix "pipeline_model_v1"
  @model_cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1)) |> Base.encode64()

  def cache_key(id), do: "#{@model_cache_prefix}/#{@model_cache_version}/#{id}"
  # Helper functions for storing and retrieving the cache
  def encode(model), do: :erlang.term_to_binary(model)
  def decode(model), do: Plug.Crypto.non_executable_binary_to_term(model, [:safe])

  def find_metadata(pipeline_id) do
    {:ok, encoded_pipeline} =
      Cacheman.fetch(:front, cache_key(pipeline_id), fn ->
        pipeline = Models.Pipeline.find(pipeline_id)

        cache_content =
          pipeline
          |> Map.take([
            :id,
            :organization_id,
            :workflow_id,
            :project_id,
            :branch_id,
            :switch_id,
            :hook_id
          ])

        {:ok, encode(cache_content)}
      end)

    decode(encoded_pipeline)
  end

  def invalidate(id) do
    cache_key(id)
    |> then(&Cacheman.delete(:front, &1))
  end

  def path(id, opts \\ []) do
    {:ok, response} = Clients.Workflow.get_path(GetPathRequest.new(last_ppl_id: id))
    path_elements = response.path |> Enum.reverse()

    opts =
      opts
      |> Keyword.put_new(:fold_skipped_blocks?, false)
      |> Keyword.put_new(:requester_id, "")

    construct_path(path_elements, opts)
  end

  def construct_path(path_elements, pipeline \\ nil, opts)

  def construct_path([], pipeline, _opts), do: pipeline

  def construct_path([path_element | path_elements], child_pipeline, opts) do
    requester_id = Keyword.get(opts, :requester_id, "")

    parent_pipeline =
      path_element.ppl_id
      |> __MODULE__.find(detailed: true)
      |> __MODULE__.preload_switch(requester_id)
      |> Diagram.load()

    parent_pipeline =
      if Keyword.get(opts, :fold_skipped_blocks?, false),
        do: Diagram.SkippedBlocks.fold_dependencies(parent_pipeline),
        else: parent_pipeline

    parent_pipeline =
      if child_pipeline do
        switch_with_pipeline = parent_pipeline.switch |> Map.put(:pipeline, child_pipeline)
        parent_pipeline |> Map.put(:switch, switch_with_pipeline)
      else
        parent_pipeline
      end

    construct_path(path_elements, parent_pipeline, opts)
  end

  def find(id, opts \\ [], _tracing_headers \\ nil) do
    case UUID.info(id) do
      {:ok, _} ->
        detailed = Keyword.get(opts, :detailed, true)

        DescribeRequest.new(ppl_id: id, detailed: detailed)
        |> Clients.Pipeline.describe()
        |> case do
          {:ok, response} ->
            construct_single(response)
        end

      {:error, _} ->
        nil
    end
  end

  def find_many(ids, _tracing_headers \\ nil) do
    request = DescribeManyRequest.new(ppl_ids: ids)

    {:ok, response} = Clients.Pipeline.describe_many(request)

    case ResponseCode.key(response.response_status.code) do
      :OK -> construct(response.pipelines)
      :BAD_PARAM -> nil
    end
  end

  def list(params \\ [], options \\ [], tracing_headers \\ nil) do
    defaults = [
      page: 1,
      page_size: 300
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
    |> Enum.map(&InternalApi.Plumber.GitRefType.value/1)
  end

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

    case Clients.Pipeline.list_keyset(req) do
      {:ok, response} ->
        {construct(response.pipelines), response.next_page_token, response.previous_page_token}

      error ->
        error
    end
  end

  @topology_cache_prefix "pipeline-model-topology"
  @topology_cache_version :crypto.hash(:md5, File.read(__ENV__.file) |> elem(1))
                          |> Base.encode64()

  def topology_cache_version do
    @topology_cache_version
  end

  def topology(pipeline_id) do
    cache_key = "#{@topology_cache_prefix}/#{topology_cache_version()}/#{pipeline_id}"

    {_status, encoded_topology} =
      Cacheman.fetch(:front, cache_key, fn ->
        request = DescribeTopologyRequest.new(ppl_id: pipeline_id)

        {:ok, response} = Clients.Pipeline.describe_topology(request)

        case {ResponseCode.key(response.status.code), Enum.empty?(response.blocks)} do
          {:OK, false} ->
            {:ok, encode(construct_from_topology(response))}

          _ ->
            # Construct but don't cache empty topology
            {:not_ok, encode(construct_from_topology(response))}
        end
      end)

    if is_nil(encoded_topology) do
      nil
    else
      decode(encoded_topology)
    end
  end

  def stop(id, requester_id, _tracing_headers \\ nil) do
    request = TerminateRequest.new(ppl_id: id, requester_id: requester_id)

    {:ok, response} = Clients.Pipeline.terminate(request)

    case ResponseCode.key(response.response_status.code) do
      :OK -> :ok
      :BAD_PARAM -> {:error, response.response_status.message}
    end
  end

  def rebuild(id, requester_id, _tracing_headers \\ nil) do
    request =
      PartialRebuildRequest.new(
        ppl_id: id,
        user_id: requester_id,
        request_token: UUID.uuid4()
      )

    {:ok, response} = Clients.Pipeline.partial_rebuild(request)

    case ResponseCode.key(response.response_status.code) do
      :OK -> {:ok, response.ppl_id}
      :BAD_PARAM -> {:error, response.response_status.message}
      _ -> {:error, "Failed to rebuild pipeline"}
    end
  end

  defp request_stream(req, tracing_headers, override \\ nil) do
    request(req, tracing_headers) |> stream_if_needed(override)
  end

  defp request(request, _tracing_headers) do
    {:ok, response} = Clients.Pipeline.list(request)

    case ResponseCode.key(response.response_status.code) do
      :OK -> {:ok, construct(response.pipelines), page(response), next_page(response), request}
      :BAD_PARAM -> {:error, nil, nil, nil, request}
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

  def construct_single(describe_response) do
    %__MODULE__{
      id: describe_response.pipeline.ppl_id,
      organization_id: describe_response.pipeline.organization_id,
      name: describe_response.pipeline.name,
      workflow_id: describe_response.pipeline.wf_id,
      state: PipelineState.key(describe_response.pipeline.state),
      result: PipelineResult.key(describe_response.pipeline.result),
      result_reason: PipelineResultReason.key(describe_response.pipeline.result_reason),
      blocks: construct_blocks(describe_response.blocks),
      project_id: describe_response.pipeline.project_id,
      branch_id: describe_response.pipeline.branch_id,
      hook_id: describe_response.pipeline.hook_id,
      timeline: %{
        created_at: describe_response.pipeline.created_at.seconds,
        pending_at: describe_response.pipeline.pending_at.seconds,
        queuing_at: describe_response.pipeline.queuing_at.seconds,
        running_at: describe_response.pipeline.running_at.seconds,
        stopping_at: describe_response.pipeline.stopping_at.seconds,
        done_at: describe_response.pipeline.done_at.seconds
      },
      error_description: describe_response.pipeline.error_description,
      switch_id: describe_response.pipeline.switch_id,
      terminated_by: describe_response.pipeline.terminated_by,
      promotion_of: describe_response.pipeline.promotion_of,
      partial_rerun_of: describe_response.pipeline.partial_rerun_of,
      compile_task: construct_compile_task(describe_response.pipeline),
      after_task: construct_after_task(describe_response.pipeline),
      env_vars: construct_env_vars(describe_response.pipeline),
      triggerer: construct_triggerer(describe_response.pipeline)
    }
  end

  defp construct_triggerer(pipeline) do
    Models.Pipeline.Triggerer.construct(pipeline)
  end

  defp construct_compile_task(pipeline) do
    task_id = pipeline.compile_task_id

    struct!(CompileTask, task_id: task_id, present?: task_id != "")
  end

  defp construct_after_task(pipeline) do
    task_id = pipeline.after_task_id
    present? = pipeline.with_after_task

    struct!(AfterTask, task_id: task_id, present?: present?, jobs: [])
  end

  defp construct_env_vars(pipeline) do
    Enum.into(pipeline.env_vars, [], &%{name: &1.name, value: &1.value})
  end

  def construct(pipelines) when is_list(pipelines) do
    pipelines
    |> Enum.map(fn pipeline -> construct(pipeline) end)
    |> preload_trigger_users()
  end

  def construct(pipeline) do
    %__MODULE__{
      id: pipeline.ppl_id,
      organization_id: pipeline.organization_id,
      name: pipeline.name,
      workflow_id: pipeline.wf_id,
      state: Pipeline.State.key(pipeline.state),
      result: Pipeline.Result.key(pipeline.result),
      result_reason: Pipeline.ResultReason.key(pipeline.result_reason),
      timeline: %{
        created_at: pipeline.created_at.seconds,
        pending_at: pipeline.pending_at.seconds,
        queuing_at: pipeline.queuing_at.seconds,
        running_at: pipeline.running_at.seconds,
        stopping_at: pipeline.stopping_at.seconds,
        done_at: pipeline.done_at.seconds,
        duration: duration(pipeline)
      },
      error_description: pipeline.error_description,
      pipeline_path: [pipeline.working_directory, pipeline.yaml_file_name] |> Path.join(),
      yaml_file_name: pipeline.yaml_file_name,
      hook_id: pipeline.hook_id,
      switch_id: pipeline.switch_id,
      branch_id: pipeline.branch_id,
      terminated_by: pipeline.terminated_by,
      project_id: pipeline.project_id,
      promotion_of: pipeline.promotion_of,
      partial_rerun_of: pipeline.partial_rerun_of,
      compile_task: construct_compile_task(pipeline),
      after_task: construct_after_task(pipeline),
      env_vars: construct_env_vars(pipeline),
      triggerer: construct_triggerer(pipeline)
    }
  end

  def construct_from_topology(describe_topology_response) do
    %__MODULE__{
      blocks:
        Enum.map(describe_topology_response.blocks, fn block ->
          Front.Models.Pipeline.Block.construct_from_topology(block)
        end),
      after_task:
        Front.Models.Pipeline.AfterTask.construct_from_topology(
          describe_topology_response.after_pipeline
        )
    }
  end

  def construct_blocks(blocks) do
    Enum.map(blocks, fn block -> Front.Models.Pipeline.Block.construct(block) end)
  end

  defmodule Block do
    alias InternalApi.Plumber.Block.Result, as: BlockResult
    alias InternalApi.Plumber.Block.ResultReason, as: BlockResultReason
    alias InternalApi.Plumber.Block.State, as: BlockState

    @enforce_keys [:name, :skipped?, :dependencies]
    defstruct [
      :id,
      :name,
      :state,
      :result,
      :build_request_id,
      :skipped?,
      :dependencies,
      :jobs
    ]

    @doc """
    A topology block does not yet have full information about a block, only the
    basics like its name and dependencies.

    A full block should be constructed with construct/1.
    """
    def construct_from_topology(topology_block) do
      struct!(__MODULE__,
        name: topology_block.name,
        dependencies: topology_block.dependencies,
        skipped?: false,
        jobs: Enum.map(topology_block.jobs, fn job_name -> %{name: job_name} end)
      )
      |> Map.from_struct()
    end

    def construct(block) do
      struct!(__MODULE__,
        id: block.block_id,
        name: block.name,
        state: BlockState.key(block.state),
        result: BlockResult.key(block.result),
        build_request_id: block.build_req_id,
        skipped?: skipped?(block),
        dependencies: [],
        jobs: Enum.map(block.jobs, fn job -> %{id: job.job_id, name: job.name} end)
      )
      |> Map.from_struct()
    end

    defp skipped?(block) do
      block.state == BlockState.value(:DONE) &&
        block.result_reason == BlockResultReason.value(:SKIPPED)
    end
  end

  defp duration(ppl) do
    cond do
      ppl.state == Pipeline.State.value(:DONE) ->
        ppl.done_at.seconds - ppl.running_at.seconds

      ppl.state == Pipeline.State.value(:RUNNING) ->
        DateTime.to_unix(DateTime.utc_now()) - ppl.running_at.seconds

      true ->
        nil
    end
  end

  def options(tracing_headers), do: [timeout: 30_000, metadata: tracing_headers]

  def preload_terminators(pipelines, tracing_headers \\ nil) do
    pipelines
    |> Enum.map(fn pipeline ->
      if terminated_by_user?(pipeline) do
        terminator = Models.User.find(pipeline.terminated_by, tracing_headers)
        pipeline |> Map.put(:terminator, terminator)
      else
        pipeline
      end
    end)
  end

  defp terminated_by_user?(pipeline) do
    # non-uuid type string indicates
    # an automatic termination by the system
    case pipeline.terminated_by |> UUID.info() do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  def preload_origins(pipelines, requester_id) do
    pipelines
    |> Enum.map(fn pipeline ->
      if pipeline.promotion_of != "" do
        origin = Models.Pipeline.find(pipeline.promotion_of)

        event =
          Models.Switch.find(origin.switch_id, requester_id)
          |> Models.Switch.find_event_by_pipeline_id(pipeline.id)

        # In below condition we have to perform additional check
        # whether the corresponding event exists in the parent switch.
        #
        # The corresponding event is missing for rebuilt promotions.
        pipeline =
          if event && promoted_manually?(event) do
            user = Models.User.find(event.triggered_by)
            Map.put(pipeline, :promoted_by, user)
          else
            pipeline
          end

        pipeline |> Map.put(:origin, origin)
      else
        pipeline
      end
    end)
  end

  def promoted_manually?(event) do
    !event.auto_triggered
  end

  def preload_switch(pipeline, requester_id) do
    pipeline
    |> Map.put(
      :switch,
      Models.Switch.find(pipeline.switch_id, requester_id)
      |> Models.Switch.preload_users()
      |> Models.Switch.preload_pipelines()
    )
  end

  defp preload_trigger_users(pipelines) when is_list(pipelines) do
    trigger_users =
      pipelines
      |> Enum.map(& &1.triggerer)
      |> Enum.flat_map(&Models.Pipeline.Triggerer.users_to_preload/1)

    user_ids =
      trigger_users
      |> Enum.map(fn {:user, {user_id, _}} -> user_id end)

    users =
      Models.User.find_many(user_ids)
      |> case do
        nil ->
          []

        users ->
          users
      end
      |> Enum.map(fn user ->
        {:user, {user.id, user.name}}
      end)

    pipelines
    |> Enum.map(fn pipeline ->
      triggerer = Models.Pipeline.Triggerer.preload_users(pipeline.triggerer, users)

      %{pipeline | triggerer: triggerer}
    end)
  end
end
