defmodule Support.Stubs.Task do
  alias Support.Stubs.{Artifacthub, DB, Time, UUID}

  @type job_stub_t :: %{
          id: Ecto.UUID.t(),
          task_id: Ecto.UUID.t(),
          api_model: InternalApi.Task.Task.Job.t()
        }

  def init do
    DB.add_table(:tasks, [:id, :api_model, :project_id, :branch_id])
    DB.add_table(:jobs, [:id, :task_id, :api_model])

    __MODULE__.Grpc.init()
    __MODULE__.Grpc.Job.init()
  end

  def create(block) do
    pipeline = DB.find(:pipelines, block.ppl_id)
    task = create_empty_task(block.api_model.build_req_id, pipeline)

    jobs =
      block.topology.jobs
      |> Enum.with_index()
      |> Enum.map(fn {name, index} ->
        create_job(task, name: name, index: index)
      end)

    # So that we can access created jobs in the block
    task = %{task | api_model: %{task.api_model | jobs: jobs}}

    DB.update(:tasks, task)
  end

  def create_empty_task(req_id, pipeline) do
    api_model =
      InternalApi.Task.Task.new(
        id: UUID.gen(),
        ppl_id: pipeline.id,
        hook_id: pipeline.api_model.hook_id,
        request_token: req_id
      )

    DB.insert(:tasks, %{
      id: api_model.id,
      api_model: api_model,
      project_id: pipeline.api_model.project_id,
      branch_id: pipeline.api_model.branch_id
    })
  end

  def create_job(task, params \\ []) do
    default = [
      id: UUID.gen(),
      state: InternalApi.Task.Task.Job.State.value(:ENQUEUED),
      created_at: Time.now(),
      enqueued_at: Time.now(),
      task_id: task.id
    ]

    api_model = default |> Keyword.merge(params) |> InternalApi.Task.Task.Job.new()

    DB.insert(:jobs, %{
      id: api_model.id,
      api_model: api_model,
      task_id: task.id
    })
  end

  def change_state(task, :running) do
    alias InternalApi.Task.Task.State

    task
    |> jobs()
    |> Enum.each(fn j -> change_job_state(j, :running) end)

    task
    |> reload()
    |> update([:api_model, :state], State.value(:RUNNING))
  end

  def change_state(task, :finished, result \\ :passed) do
    alias InternalApi.Task.Task.State

    task
    |> jobs()
    |> Enum.each(fn j -> change_job_state(j, :finished, result) end)

    task
    |> reload()
    |> update([:api_model, :state], State.value(:FINISHED))
  end

  def change_job_state(job, :running) do
    job
    |> reload_job()
    |> update_job([:api_model, :state], InternalApi.Task.Task.Job.State.value(:RUNNING))
    |> update_job([:api_model, :started_at], Time.now())
  end

  def change_job_state(job, :finished, result \\ :passed) do
    job
    |> reload_job()
    |> update_job([:api_model, :state], InternalApi.Task.Task.Job.State.value(:FINISHED))
    |> update_job([:api_model, :started_at], Time.now())
    |> update_job([:api_model, :finished_at], Time.now())
    |> update_job([:api_model, :result], encode_job_result(result))
  end

  @spec add_job_artifact(job_stub_t(), url: String.t(), path: String.t()) :: any()
  def add_job_artifact(job, params \\ []) do
    params = Keyword.merge(params, scope: "jobs")
    Artifacthub.create(job.id, params)
  end

  defp encode_job_result(result) do
    cond do
      result == :failed ->
        InternalApi.Task.Task.Job.Result.value(:FAILED)

      result == :passed ->
        InternalApi.Task.Task.Job.Result.value(:PASSED)

      true ->
        raise "unknown job result"
    end
  end

  def reload(task) do
    DB.find(:tasks, task.id)
  end

  def reload_job(job) do
    DB.find(:jobs, job.id)
  end

  def jobs(task) do
    DB.find_all_by(:jobs, :task_id, task.id)
  end

  def update(task, location, value) do
    location = Enum.map(location, fn l -> Access.key(l) end)
    new_task = put_in(task, location, value)

    DB.update(:tasks, new_task)
  end

  defp update_job(job, location, value) do
    location = Enum.map(location, fn l -> Access.key(l) end)
    new_job = put_in(job, location, value)

    DB.update(:jobs, new_job)
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(TaskMock, :describe_many, &__MODULE__.describe_many/2)
    end

    def describe_many(_req, _) do
      tasks =
        DB.all(:tasks)
        |> DB.extract(:api_model)
        |> Enum.map(fn t ->
          jobs = DB.find_all_by(:jobs, :task_id, t.id) |> DB.extract(:api_model)

          Map.merge(t, %{jobs: jobs})
        end)

      InternalApi.Task.DescribeManyResponse.new(tasks: tasks)
    end
  end

  defmodule Grpc.Job do
    def init do
      GrpcMock.stub(InternalJobMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(InternalJobMock, :list_debug_sessions, &__MODULE__.list_debug_sessions/2)
      GrpcMock.stub(InternalJobMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(InternalJobMock, :can_debug, &__MODULE__.can_debug/2)
      GrpcMock.stub(InternalJobMock, :can_attach, &__MODULE__.can_attach/2)
    end

    def describe(req, _) do
      alias InternalApi.ServerFarm.Job.DescribeResponse
      alias InternalApi.ServerFarm.Job.Job

      job = DB.find(:jobs, req.job_id)
      task = DB.find(:tasks, job.task_id)
      task_job = job |> DB.extract(:api_model)

      DescribeResponse.new(
        status: ok(),
        job:
          Job.new(
            id: task_job.id,
            project_id: task.project_id,
            branch_id: task.branch_id,
            hook_id: task.api_model.hook_id,
            ppl_id: task.api_model.ppl_id,
            timeline: Job.Timeline.new(),
            state: Job.State.value(:STARTED),
            machine_type: "e1-standard-2",
            self_hosted: false,
            name: task_job.name,
            index: task_job.index
          )
      )
    end

    def list_debug_sessions(_, _) do
      InternalApi.ServerFarm.Job.ListDebugSessionsResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        debug_sessions: [Support.Factories.debug_session(), Support.Factories.debug_session()],
        next_page_token: "123"
      )
    end

    def list(_, _) do
      InternalApi.ServerFarm.Job.ListResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        jobs: [],
        next_page_token: ""
      )
    end

    def can_debug(_, _) do
      InternalApi.ServerFarm.Job.CanDebugResponse.new(allowed: true)
    end

    def can_attach(_, _) do
      InternalApi.ServerFarm.Job.CanAttachResponse.new(allowed: false)
    end

    defp ok do
      InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
    end
  end
end
