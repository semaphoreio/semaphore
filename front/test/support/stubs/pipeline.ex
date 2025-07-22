defmodule Support.Stubs.Pipeline do
  alias Support.Stubs.{
    Artifacthub,
    DB,
    Time,
    UUID,
    Velocity
  }

  @type pipeline_t :: %{
          id: Ecto.UUID.t(),
          wf_id: Ecto.UUID.t(),
          api_model: InternalApi.Plumber.Pipeline.t()
        }

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
    alias InternalApi.Plumber.Pipeline.{Result, State}
    alias InternalApi.Plumber.{TriggeredBy, Triggerer}

    defaults = [
      name: "Build & Test",
      ppl_id: UUID.gen(),
      organization_id: UUID.gen(),
      project_id: workflow.api_model.project_id,
      branch_id: workflow.api_model.branch_id,
      branch_name: workflow.api_model.branch_name,
      hook_id: workflow.api_model.hook_id,
      commit_sha: workflow.api_model.commit_sha,
      state: State.value(:QUEUING),
      result: Result.value(:PASSED),
      created_at: Time.now(),
      pending_at: Time.now(),
      queuing_at: Time.now(),
      running_at: Time.now(),
      stopping_at: Time.now(),
      done_at: Time.now(),
      switch_id: "",
      error_description: "",
      terminated_by: "",
      wf_id: workflow.id,
      after_task_id: "",
      with_after_task: false,
      triggerer:
        Triggerer.new(%{
          wf_triggered_by: workflow.api_model.triggered_by,
          wf_triggerer_id: workflow.api_model.hook_id,
          wf_triggerer_user_id: workflow.api_model.requester_id,
          wf_triggerer_provider_login: "",
          wf_triggerer_provider_uid: "provider_uid",
          wf_triggerer_provider_avatar: "",
          ppl_triggered_by: TriggeredBy.value(:WORKFLOW),
          ppl_triggerer_id: workflow.id,
          ppl_triggerer_user_id: workflow.api_model.requester_id,
          workflow_rerun_of: workflow.api_model.rerun_of
        })
    ]

    api_model = defaults |> Keyword.merge(params) |> InternalApi.Plumber.Pipeline.new()

    after_pipeline = InternalApi.Plumber.DescribeTopologyResponse.AfterPipeline.new()

    api_model =
      if api_model.state == State.value(:DONE) do
        Velocity.create_pipeline_summary(pipeline_id: api_model.ppl_id)
      else
        api_model
      end

    DB.insert(:pipelines, %{
      id: api_model.ppl_id,
      wf_id: workflow.id,
      api_model: api_model,
      after_pipeline: after_pipeline
    })
  end

  def with_summary(pipeline, params \\ []) do
    params =
      [
        pipeline_id: pipeline.api_model.ppl_id
      ]
      |> Keyword.merge(params)

    Velocity.create_pipeline_summary(params)
  end

  def set_error(pipeline_id, err) do
    pipeline = DB.find(:pipelines, pipeline_id)

    api_model = Map.put(pipeline.api_model, :error_description, err)
    pipeline = Map.put(pipeline, :api_model, api_model)

    DB.update(:pipelines, pipeline)
  end

  def add_compile_task(pipeline_id) do
    pipeline = DB.find(:pipelines, pipeline_id)

    task = Support.Stubs.Task.create_empty_task(pipeline_id, pipeline)
    Support.Stubs.Task.create_job(task, name: "Compile", index: 0)

    api_model = Map.put(pipeline.api_model, :compile_task_id, task.id)
    pipeline = Map.put(pipeline, :api_model, api_model)

    DB.update(:pipelines, pipeline)

    task
  end

  def add_after_task(pipeline_id, params \\ %{}) do
    defaults = %{
      jobs: [%{name: "Clean"}],
      task_created: false
    }

    params = defaults |> Map.merge(params)

    task_created = Map.get(params, :task_created)

    job_params =
      Map.get(params, :jobs)
      |> Enum.with_index()
      |> Enum.map(fn {job, index} ->
        name = Map.get(job, :name, "job_#{index}")
        [name: name, index: index]
      end)

    pipeline = DB.find(:pipelines, pipeline_id)

    {after_task_id, after_pipeline_jobs} =
      task_created
      |> case do
        true ->
          task = Support.Stubs.Task.create_empty_task(pipeline_id, pipeline)

          after_pipeline_jobs =
            job_params
            |> Enum.map(fn job_params ->
              %{api_model: %{name: job_name}} = Support.Stubs.Task.create_job(task, job_params)
              job_name
            end)

          {task.id, after_pipeline_jobs}

        _ ->
          {"", job_params |> Enum.map(& &1[:name])}
      end

    after_pipeline =
      InternalApi.Plumber.DescribeTopologyResponse.AfterPipeline.new(jobs: after_pipeline_jobs)

    api_model =
      pipeline.api_model
      |> Map.put(:after_task_id, after_task_id)
      |> Map.put(:with_after_task, true)

    pipeline =
      pipeline
      |> Map.put(:api_model, api_model)
      |> Map.put(:after_pipeline, after_pipeline)

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
    job_names = Map.get(params, :job_names, ["job 1", "job 2", "job 3"])

    block =
      Block.new(
        block_id: UUID.gen(),
        name: name,
        build_req_id: UUID.gen(),
        state: Block.State.value(state)
      )

    topology =
      DescribeTopologyResponse.Block.new(
        name: name,
        jobs: job_names,
        dependencies: params[:dependencies] || []
      )

    DB.insert(:blocks, %{
      id: block.block_id,
      ppl_id: pipeline.id,
      api_model: block,
      topology: topology
    })
  end

  @spec add_artifact(pipeline_t(), url: String.t(), path: String.t()) :: any()
  def add_artifact(pipeline, params \\ []) do
    params = Keyword.merge(params, scope: "pipelines")
    Artifacthub.create(pipeline.id, params)
  end

  def change_state(pipeline_id, state) do
    alias InternalApi.Plumber.Pipeline.{Result, State}

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

    Cacheman.clear(:front)
    DB.update(:pipelines, pipeline)
  end

  def initializing?(pipeline) do
    alias InternalApi.Plumber.Pipeline.State

    pipeline.api_model.state == State.value(:INITIALIZING)
  end

  defmodule Grpc do
    alias InternalApi.Plumber.DescribeManyResponse
    alias InternalApi.Plumber.DescribeResponse
    alias InternalApi.Plumber.DescribeTopologyResponse
    alias InternalApi.Plumber.ListKeysetResponse
    alias InternalApi.Plumber.ListResponse
    alias Support.Stubs.DB

    def init do
      GrpcMock.stub(PipelineMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(PipelineMock, :describe_many, &__MODULE__.describe_many/2)
      GrpcMock.stub(PipelineMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(PipelineMock, :list_keyset, &__MODULE__.list_keyset/2)
      GrpcMock.stub(PipelineMock, :describe_topology, &__MODULE__.describe_topology/2)
      GrpcMock.stub(PipelineMock, :terminate, &__MODULE__.terminate/2)
      GrpcMock.stub(PipelineMock, :partial_rebuild, &__MODULE__.partial_rebuild/2)
    end

    def terminate(_req, _) do
      InternalApi.Plumber.TerminateResponse.new(response_status: ok())
    end

    def partial_rebuild(_req, _) do
      # Create a new pipeline for the partial rebuild
      new_pipeline_id = Support.Stubs.UUID.gen()

      InternalApi.Plumber.PartialRebuildResponse.new(
        response_status: ok(),
        ppl_id: new_pipeline_id
      )
    end

    def describe(req, _) do
      case DB.find(:pipelines, req.ppl_id) do
        nil ->
          DescribeResponse.new(response_status: bad_param())

        ppl ->
          blocks = DB.find_all_by(:blocks, :ppl_id, req.ppl_id) |> DB.extract(:api_model)

          DescribeResponse.new(response_status: ok(), pipeline: ppl.api_model, blocks: blocks)
      end
    end

    def list(req, _) do
      pipelines =
        DB.all(:pipelines)
        |> DB.extract(:api_model)
        |> filter(req)

      ListResponse.new(response_status: ok(), pipelines: pipelines)
    end

    def list_keyset(_req, _) do
      pipelines = DB.all(:pipelines) |> DB.extract(:api_model)

      ListKeysetResponse.new(pipelines: pipelines, next_page_token: "", previous_page_token: "")
    end

    def describe_many(req, _) do
      pipelines =
        DB.find_many(:pipelines, req.ppl_ids)
        |> DB.extract(:api_model)
        |> filter(req)
        |> Enum.map(fn ppl ->
          blocks = DB.find_all_by(:blocks, :ppl_id, ppl.ppl_id) |> DB.extract(:api_model)
          Map.update(ppl, :blocks, blocks, fn _ -> blocks end)
        end)

      DescribeManyResponse.new(response_status: ok(), pipelines: pipelines)
    end

    def describe_topology(req, _) do
      pipeline = DB.find(:pipelines, req.ppl_id)
      after_pipeline = pipeline.after_pipeline

      if Support.Stubs.Pipeline.initializing?(pipeline) do
        DescribeTopologyResponse.new(status: ok(), blocks: [], after_pipeline: after_pipeline)
      else
        topology = DB.find_all_by(:blocks, :ppl_id, req.ppl_id) |> DB.extract(:topology)

        DescribeTopologyResponse.new(
          status: ok(),
          blocks: topology,
          after_pipeline: after_pipeline
        )
      end
    end

    defp ok do
      code = InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
      InternalApi.Plumber.ResponseStatus.new(code: code)
    end

    defp bad_param do
      code = InternalApi.Plumber.ResponseStatus.ResponseCode.value(:BAD_PARAM)
      InternalApi.Plumber.ResponseStatus.new(code: code)
    end

    defp filter(pipelines, req) do
      req
      |> Map.from_struct()
      |> Enum.reduce(pipelines, fn
        {:wf_id, workflow_id}, pipelines ->
          pipelines
          |> Enum.filter(&(&1.wf_id == workflow_id))

        _, pipelines ->
          pipelines
      end)
    end
  end
end
