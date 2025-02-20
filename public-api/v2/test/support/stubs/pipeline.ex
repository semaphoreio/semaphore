defmodule Support.Stubs.Pipeline do
  alias Support.Stubs.{DB, Time}

  def init do
    DB.add_table(:pipelines, [:id, :wf_id, :api_model, :after_pipeline])
    DB.add_table(:blocks, [:id, :ppl_id, :api_model, :topology])

    __MODULE__.Grpc.init()
  end

  def create_initial(workflow, params \\ []) do
    params = params |> Keyword.merge(ppl_id: workflow.api_model.initial_ppl_id)

    create(workflow, params)
  end

  def create(workflow, params \\ []) do
    alias InternalApi.Plumber.Queue
    alias InternalApi.Plumber.Pipeline.State
    alias InternalApi.Plumber.Pipeline.Result

    params_with_defaults =
      [
        name: "Build & Test",
        ppl_id: UUID.uuid4(),
        project_id: workflow.api_model.project_id,
        branch_id: workflow.api_model.branch_id,
        hook_id: workflow.api_model.hook_id,
        organization_id: UUID.uuid4(),
        branch_name: "",
        commit_sha: "",
        state: State.value(:QUEUING),
        result: Result.value(:PASSED),
        created_at: Time.now(),
        pending_at: Time.now(),
        queuing_at: Time.now(),
        running_at: Time.now(),
        stopping_at: Time.now(),
        done_at: Time.now(),
        queue: %Queue{queue_id: UUID.uuid4(), name: "prod", scope: "project"},
        switch_id: "",
        error_description: "",
        terminated_by: "",
        wf_id: workflow.id,
        after_task_id: "",
        with_after_task: false,
        working_directory: "",
        yaml_file_name: ""
      ]
      |> Keyword.merge(params)

    api_model = struct(InternalApi.Plumber.Pipeline, params_with_defaults)

    after_pipeline = %InternalApi.Plumber.DescribeTopologyResponse.AfterPipeline{}

    DB.insert(:pipelines, %{
      id: api_model.ppl_id,
      wf_id: workflow.id,
      api_model: api_model,
      after_pipeline: after_pipeline
    })
  end

  def set_error(pipeline_id, err) do
    pipeline = DB.find(:pipelines, pipeline_id)

    api_model = Map.put(pipeline.api_model, :error_description, err)
    pipeline = Map.put(pipeline, :api_model, api_model)

    DB.update(:pipelines, pipeline)
  end

  def add_switch(pipeline) do
    switch = Support.Stubs.Switch.create(pipeline.id)

    api_model = Map.put(pipeline.api_model, :switch_id, switch.id)
    pipeline = Map.put(pipeline, :api_model, api_model)

    DB.update(:pipelines, pipeline)

    switch
  end

  def add_blocks(pipeline, block_params) do
    block_params |> Enum.map(fn b -> add_block(pipeline, b) end)
  end

  def add_block(pipeline, params \\ %{}) do
    alias InternalApi.Plumber.Block
    alias InternalApi.Plumber.DescribeTopologyResponse

    name = Map.get(params, :name) || "Block 1"
    state = Map.get(params, :state, :RUNNING)
    result = Map.get(params, :state, :PASSED)
    job_names = Map.get(params, :job_names, ["job 1", "job 2", "job 3"])

    block = %Block{
      block_id: Map.get(params, :block_id) || UUID.uuid4(),
      name: name,
      build_req_id: Map.get(params, :build_req_id) || UUID.uuid4(),
      state: Block.State.value(state),
      result: Block.Result.value(result)
    }

    topology = %DescribeTopologyResponse.Block{
      name: name,
      jobs: job_names,
      dependencies: params[:dependencies] || []
    }

    DB.insert(:blocks, %{
      id: block.block_id,
      ppl_id: pipeline.id,
      api_model: block,
      topology: topology
    })
  end

  def change_state(pipeline_id, state) do
    alias InternalApi.Plumber.Pipeline.{State, Result}

    change_blocks_state(pipeline_id, state)
    pipeline = DB.find(:pipelines, pipeline_id)

    api_model =
      state
      |> case do
        :initializing ->
          pipeline.api_model
          |> Map.put(:state, State.value(:INITIALIZING))

        :running ->
          pipeline.api_model
          |> Map.put(:state, State.value(:RUNNING))

        :passed ->
          pipeline.api_model
          |> Map.put(:state, State.value(:DONE))
          |> Map.put(:result, Result.value(:PASSED))

        :failed ->
          pipeline.api_model
          |> Map.put(:state, State.value(:DONE))
          |> Map.put(:result, Result.value(:FAILED))

        :stopping ->
          pipeline.api_model
          |> Map.put(:state, State.value(:STOPPING))

        :canceled ->
          pipeline.api_model
          |> Map.put(:state, State.value(:DONE))
          |> Map.put(:result, Result.value(:CANCELED))

        :pending ->
          pipeline.api_model
          |> Map.put(:state, State.value(:PENDING))

        :stopped ->
          pipeline.api_model
          |> Map.put(:state, State.value(:DONE))
          |> Map.put(:result, Result.value(:STOPPED))
      end

    pipeline = Map.put(pipeline, :api_model, api_model)

    DB.update(:pipelines, pipeline)
  end

  defp change_blocks_state(pipeline_id, state) do
    DB.find_all_by(:blocks, :ppl_id, pipeline_id)
    |> Enum.each(fn block ->
      change_block_state(block, state)
    end)
  end

  defp change_block_state(block, state) do
    alias InternalApi.Plumber.Block.{State, Result}

    api_model =
      state
      |> case do
        :initializing ->
          block.api_model
          |> Map.put(:state, State.value(:INITIALIZING))

        :running ->
          block.api_model
          |> Map.put(:state, State.value(:RUNNING))

        :passed ->
          block.api_model
          |> Map.put(:state, State.value(:DONE))
          |> Map.put(:result, Result.value(:PASSED))

        :failed ->
          block.api_model
          |> Map.put(:state, State.value(:DONE))
          |> Map.put(:result, Result.value(:FAILED))

        :stopping ->
          block.api_model
          |> Map.put(:state, State.value(:STOPPING))

        :canceled ->
          block.api_model
          |> Map.put(:state, State.value(:DONE))
          |> Map.put(:result, Result.value(:CANCELED))

        :pending ->
          block.api_model
          |> Map.put(:state, State.value(:WAITING))

        :stopped ->
          block.api_model
          |> Map.put(:state, State.value(:DONE))
          |> Map.put(:result, Result.value(:STOPPED))
      end

    new_block = Map.put(block, :api_model, api_model)
    DB.update(:blocks, new_block)
  end

  def initializing?(pipeline) do
    alias InternalApi.Plumber.Pipeline.State

    pipeline.api_model.state == State.value(:INITIALIZING)
  end

  defmodule Grpc do
    alias InternalApi.Plumber.ListKeysetResponse
    alias Support.Stubs.DB

    alias InternalApi.Plumber.{
      DescribeResponse,
      ListResponse,
      DescribeTopologyResponse,
      GetProjectIdResponse,
      VersionResponse,
      ValidateYamlResponse,
      PartialRebuildResponse
    }

    def init do
      GrpcMock.stub(PipelineMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(PipelineMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(PipelineMock, :list_keyset, &__MODULE__.list_keyset/2)
      GrpcMock.stub(PipelineMock, :describe_topology, &__MODULE__.describe_topology/2)
      GrpcMock.stub(PipelineMock, :terminate, &__MODULE__.terminate/2)
      GrpcMock.stub(PipelineMock, :get_project_id, &__MODULE__.get_project_id/2)
      GrpcMock.stub(PipelineMock, :version, &__MODULE__.version/2)
      GrpcMock.stub(PipelineMock, :validate_yaml, &__MODULE__.validate_yaml/2)
      GrpcMock.stub(PipelineMock, :partial_rebuild, &__MODULE__.partial_rebuild/2)
    end

    def partial_rebuild(req, _) do
      case DB.find(:pipelines, req.ppl_id) do
        nil ->
          %PartialRebuildResponse{response_status: bad_param("")}

        ppl ->
          partial_rebuild_(ppl, req)
      end
    end

    defp partial_rebuild_(ppl, req) do
      cond do
        req.request_token == "" ->
          %PartialRebuildResponse{
            response_status: bad_param("Missing required post parameter request_token.")
          }

        ppl.api_model.state == InternalApi.Plumber.Pipeline.State.value(:RUNNING) ->
          %PartialRebuildResponse{
            response_status:
              bad_param("Only pipelines which are in done state can be partial rebuilt.")
          }

        ppl.api_model.result == InternalApi.Plumber.Pipeline.Result.value(:PASSED) ->
          %PartialRebuildResponse{
            response_status: bad_param("Pipelines which passed can not be partial rebuilt.")
          }

        true ->
          %PartialRebuildResponse{response_status: ok(""), ppl_id: UUID.uuid4()}
      end
    end

    def validate_yaml(req, _) do
      with {:ok, data} <- YamlElixir.read_from_string(req.yaml_definition),
           true <- is_map(data) do
        %ValidateYamlResponse{
          response_status: ok("YAML definition is valid."),
          ppl_id: req.ppl_id
        }
      else
        _ ->
          %ValidateYamlResponse{
            response_status:
              bad_param("{:malformed, {:expected_map, \"#{req.yaml_definition}\"}}"),
            ppl_id: req.ppl_id
          }
      end
    end

    def version(_, _) do
      %VersionResponse{version: "0.1.0"}
    end

    def get_project_id(req, _) do
      case DB.find(:pipelines, req.ppl_id) do
        nil ->
          %GetProjectIdResponse{response_status: bad_param("")}

        ppl ->
          %GetProjectIdResponse{response_status: ok(""), project_id: ppl.api_model.project_id}
      end
    end

    def terminate(req, _) do
      case DB.find(:pipelines, req.ppl_id) do
        nil ->
          %InternalApi.Plumber.TerminateResponse{response_status: bad_param("")}

        ppl ->
          new_ppl = Map.merge(ppl.api_model, %{terminated_by: req.requester_id})

          DB.update(:pipelines, %{
            id: req.ppl_id,
            wf_id: ppl.wf_id,
            api_model: new_ppl,
            after_pipeline: ppl.after_pipeline
          })

          Support.Stubs.Pipeline.change_state(ppl.id, :stopped)

          %InternalApi.Plumber.TerminateResponse{
            response_status: ok("Pipeline termination started.")
          }
      end
    end

    def describe(req, _) do
      case DB.find(:pipelines, req.ppl_id) do
        nil ->
          %DescribeResponse{response_status: bad_param("")}

        ppl ->
          blocks = DB.find_all_by(:blocks, :ppl_id, req.ppl_id) |> DB.extract(:api_model)
          %DescribeResponse{response_status: ok(""), pipeline: ppl.api_model, blocks: blocks}
      end
    end

    def list(req, _) do
      pipelines =
        DB.all(:pipelines)
        |> DB.extract(:api_model)
        |> filter(req)
        |> Enum.sort_by(fn w -> w.created_at.seconds end, &>=/2)

      pages =
        pipelines
        |> Enum.chunk_every(req.page_size)

      page = pages |> Enum.at(req.page - 1)

      %ListResponse{
        response_status: ok(""),
        pipelines: page,
        page_number: req.page,
        page_size: req.page_size,
        total_entries: Enum.count(page),
        total_pages: Enum.count(pages)
      }
    end

    def list_keyset(req, _) do
      pipelines =
        DB.all(:pipelines)
        |> DB.extract(:api_model)
        |> filter(req)
        |> Enum.sort_by(fn w -> w.created_at.seconds end, &>=/2)

      pages =
        pipelines
        |> Enum.chunk_every(req.page_size)

      # find page that has the first pipeline id == too req.page_token
      # and for next_page_token if there is a next page use the first pipeline id from next page

      {page, next_page_token} =
        case req.page_token do
          "" ->
            page = pages |> Enum.at(0)

            if Enum.count(pages) > 1 do
              next_page_token = (Enum.at(pages, 1) |> Enum.at(0)).id
              {page, next_page_token}
            else
              {page, ""}
            end

          _ ->
            page = pages |> Enum.find(fn p -> Enum.at(p, 0).id == req.page_token end)
            # implement next page token if needed
            {page, ""}
        end

      %ListKeysetResponse{
        pipelines: page,
        next_page_token: next_page_token,
        previous_page_token: ""
      }
    end

    def describe_topology(req, _) do
      pipeline = DB.find(:pipelines, req.ppl_id)
      after_pipeline = pipeline.after_pipeline

      if Support.Stubs.Pipeline.initializing?(pipeline) do
        %DescribeTopologyResponse{status: ok(""), blocks: [], after_pipeline: after_pipeline}
      else
        topology = DB.find_all_by(:blocks, :ppl_id, req.ppl_id) |> DB.extract(:topology)

        %DescribeTopologyResponse{
          status: ok(""),
          blocks: topology,
          after_pipeline: after_pipeline
        }
      end
    end

    defp ok(message) do
      code = InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
      %InternalApi.Plumber.ResponseStatus{code: code, message: message}
    end

    defp bad_param(message) do
      code = InternalApi.Plumber.ResponseStatus.ResponseCode.value(:BAD_PARAM)
      %InternalApi.Plumber.ResponseStatus{code: code, message: message}
    end

    defp filter(pipelines, req) do
      pipelines
      |> filter_by_wf_id(req)
      |> filter_by_project_id(req)
    end

    defp filter_by_wf_id(pipelines, %{wf_id: ""}), do: pipelines

    defp filter_by_wf_id(pipelines, %{wf_id: wf_id}) do
      pipelines
      |> Enum.filter(fn p -> p.wf_id == wf_id end)
    end

    defp filter_by_project_id(pipelines, %{project_id: ""}), do: pipelines

    defp filter_by_project_id(pipelines, %{project_id: project_id}) do
      pipelines
      |> Enum.filter(fn p -> p.project_id == project_id end)
    end
  end
end
