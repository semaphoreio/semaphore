defmodule Zebra.Apis.InternalTaskApiTest do
  use Zebra.DataCase

  alias InternalApi.Task.TaskService.Stub, as: Stub
  alias Zebra.Apis.InternalTaskApi.Serializer

  @req_token Ecto.UUID.generate()

  describe ".schedule" do
    test "scheduling with zero jobs => invalid" do
      req = InternalApi.Task.ScheduleRequest.new(jobs: [])

      assert {:error, e} = Stub.schedule(channel(), req)
      assert e == %GRPC.RPCError{message: "A task must have at least one job", status: 3}
    end

    test "first time scheduling => created new task" do
      req = construct_example_schedule_request(@req_token)

      Stub.schedule(channel(), req)

      assert {:ok, task} = Zebra.Models.Task.find_by_request_token(@req_token)
      assert task.build_request_id == @req_token
    end

    test "first time scheduling => returns task_id" do
      req = construct_example_schedule_request(@req_token)

      {:ok, reply} = Stub.schedule(channel(), req)

      assert {:ok, task} = Zebra.Models.Task.find_by_request_token(@req_token)
      assert reply.task.id == task.id
    end

    test "second time scheduling with same token => returns existing task" do
      req = construct_example_schedule_request(@req_token)

      # first time scheduling
      {:ok, reply1} = Stub.schedule(channel(), req)

      # second time scheduling
      {:ok, reply2} = Stub.schedule(channel(), req)

      assert reply1.task.id == reply2.task.id
    end

    test "schedule creates a task with all its jobs" do
      req = construct_example_schedule_request(@req_token)

      Stub.schedule(channel(), req)

      assert {:ok, task} = Zebra.Models.Task.find_by_request_token(@req_token)

      task = Zebra.LegacyRepo.preload(task, [:jobs])

      assert Enum.count(task.jobs) == 2
    end
  end

  describe ".describe" do
    test "task not found => returns GRPC :not_found" do
      req = InternalApi.Task.DescribeRequest.new(task_id: Ecto.UUID.generate())

      assert {:error, e} = Stub.describe(channel(), req)
      assert e.status == GRPC.Status.not_found()
    end

    test "task found => returns serialized task" do
      task_id = schedule_task()

      req = InternalApi.Task.DescribeRequest.new(task_id: task_id)

      assert {:ok, reply} = Stub.describe(channel(), req)

      {:ok, task} = Zebra.Models.Task.find(task_id)

      assert reply.task == Serializer.serialize(task)
    end
  end

  describe ".describe_many" do
    test "tasks found => returns serialized tasks" do
      task_id1 = schedule_task(Ecto.UUID.generate())
      task_id2 = schedule_task(Ecto.UUID.generate())

      task_ids = [task_id1, task_id2]

      assert {:ok, tasks} = Zebra.Models.Task.find_many(task_ids)

      req = InternalApi.Task.DescribeManyRequest.new(task_ids: task_ids)

      assert {:ok, reply} = Stub.describe_many(channel(), req)
      assert reply.tasks == Serializer.serialize_many(tasks)
    end
  end

  describe ".terminate" do
    test "task not found => returns GRCP :not_found" do
      req = InternalApi.Task.TerminateRequest.new(task_id: Ecto.UUID.generate())

      assert {:error, e} = Stub.terminate(channel(), req)
      assert e.status == GRPC.Status.not_found()
    end

    test "task found => terminates task" do
      task_id = schedule_task()

      req = InternalApi.Task.TerminateRequest.new(task_id: task_id)

      assert {:ok, reply} = Stub.terminate(channel(), req)
      assert reply == InternalApi.Task.TerminateResponse.new(message: "Terminated #{task_id}")
    end

    test "requests async stop for all jobs" do
      task_id = schedule_task()

      req = InternalApi.Task.TerminateRequest.new(task_id: task_id)

      assert {:ok, _} = Stub.terminate(channel(), req)

      {:ok, task} = Zebra.Models.Task.find(task_id)

      task = Zebra.LegacyRepo.preload(task, [:jobs])
      assert length(task.jobs) > 0

      task.jobs
      |> Enum.each(fn j ->
        req =
          Zebra.LegacyRepo.one(from(r in Zebra.Models.JobStopRequest, where: r.job_id == ^j.id))

        assert req.job_id == j.id
        assert req.build_id == j.build_id
      end)
    end

    test "repeated calls" do
      task_id = schedule_task()

      req = InternalApi.Task.TerminateRequest.new(task_id: task_id)

      assert {:ok, reply} = Stub.terminate(channel(), req)
      assert reply == InternalApi.Task.TerminateResponse.new(message: "Terminated #{task_id}")

      assert {:ok, reply} = Stub.terminate(channel(), req)
      assert reply == InternalApi.Task.TerminateResponse.new(message: "Terminated #{task_id}")
    end
  end

  #
  # Utils
  #

  def construct_example_schedule_request(token) do
    alias InternalApi.Task.ScheduleRequest, as: R

    agent =
      R.Job.Agent.new(
        machine:
          R.Job.Agent.Machine.new(
            type: "e1-standard-2",
            os_image: "ubuntu1804"
          ),
        containers: [
          R.Job.Agent.Container.new(
            name: "main",
            image: "postgres:9.6",
            env_vars: [
              R.Job.EnvVar.new(name: "A", value: "B")
            ],
            secrets: [
              R.Job.Secret.new(name: "A")
            ]
          )
        ],
        image_pull_secrets: [
          R.Job.Agent.ImagePullSecret.new(name: "A")
        ]
      )

    job1 =
      R.Job.new(
        name: "Papa",
        agent: agent,
        env_vars: [
          R.Job.EnvVar.new(name: "A", value: "B")
        ],
        secrets: [
          R.Job.Secret.new(name: "A")
        ],
        prologue_commands: [
          "echo 'prologue'"
        ],
        commands: [
          "echo 'cmd'"
        ],
        epilogue_always_commands: [
          "echo 'epilogue'"
        ]
      )

    job2 =
      R.Job.new(
        name: "Papa2",
        agent: agent,
        env_vars: [
          R.Job.EnvVar.new(name: "B", value: "C")
        ],
        secrets: [
          R.Job.Secret.new(name: "koi")
        ],
        prologue_commands: [
          "echo 'prologue'"
        ],
        commands: [
          "echo 'cmd'"
        ],
        epilogue_always_commands: [
          "echo 'epilogue'"
        ]
      )

    R.new(
      jobs: [job1, job2],
      request_token: token,
      ppl_id: Ecto.UUID.generate(),
      hook_id: Ecto.UUID.generate(),
      wf_id: Ecto.UUID.generate(),
      project_id: Ecto.UUID.generate(),
      repository_id: Ecto.UUID.generate(),
      org_id: Ecto.UUID.generate()
    )
  end

  def channel do
    {:ok, c} = GRPC.Stub.connect("localhost:50051")

    c
  end

  def schedule_task(token \\ @req_token) do
    req = construct_example_schedule_request(token)
    {:ok, reply} = Stub.schedule(channel(), req)
    reply.task.id
  end
end
