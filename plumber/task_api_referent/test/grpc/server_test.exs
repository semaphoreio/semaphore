defmodule TaskApiReferent.GRPC.Server do
  use ExUnit.Case

  alias Util.Proto
  alias TaskApiReferent.Service
  alias InternalApi.Task.{ScheduleRequest, Task, TaskService, TerminateRequest,
                          DescribeRequest, DescribeManyRequest}

  setup do
    env_var_1 = %{name: "TEST", value: "this is just a test!\n"}
    env_var_2 = %{name: "JOB", value: "JOB ENV VAR"}

    secret = %{name: "secret"}

    valid_job_1 = %{commands: ["echo hello", "echo hi"], secrets: [secret]}
    valid_job_2 = %{commands: ["echo hows it going"], secrets: [secret]}
    env_vars_job_1 = %{commands: ["echo $TEST"], env_vars: [env_var_1]}
    env_vars_job_2 = %{commands: ["if [[ $JOB == \"JOB ENV VAR\" ]]; then exit 0 ; else exit 127; fi"],
                      env_vars: [env_var_2]}
    prologue_job = %{commands: ["cd prologue"], prologue_commands: ["mkdir prologue"]}
    epilogue_job = %{commands: ["echo hello", "echo hi"], epilogue_always_cmds: ["mkdir always"],
                     epilogue_on_pass_cmds: ["mkdir on_pass"], epilogue_on_fail_cmds: ["mkdir on_fail"]}
    stop_job = %{commands: ["sleep 3", "echo foo", "sleep 5", "echo bar"]}
    invalid_job = %{commands: ["invalid command"]}

    {:ok, %{valid_job_1: valid_job_1, valid_job_2: valid_job_2,
           env_vars_job_1: env_vars_job_1, env_vars_job_2: env_vars_job_2,
           prologue_job: prologue_job, epilogue_job: epilogue_job,
           stop_job: stop_job, invalid_job: invalid_job}}
  end

  # Schedule

  test "gRPC schedule - returns task description when request is valid", ctx do
    request =
      %{request_token: UUID.uuid4(), ppl_id: UUID.uuid4(), wf_id: UUID.uuid4(),
        jobs: [ctx.valid_job_1, ctx.valid_job_2]}
        |> Proto.deep_new!(ScheduleRequest)

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, %{task: task = %Task{}}} = TaskService.Stub.schedule(channel, request)

    task = task |> Proto.to_map!()
    assert {:ok, _} = UUID.info(task.id)
    assert task.state == :RUNNING
    assert task.result == :FAILED
    assert task.ppl_id == request.ppl_id
    assert task.wf_id == request.wf_id

    :timer.sleep(1000)
    {:ok, task} = Service.Task.get(task.id)
    assert Map.get(task, :state) == :FINISHED
    assert Map.get(task, :result) == :PASSED
  end

  test "gRPC schedule - env vars are exported", ctx do
    request =
      %{request_token: UUID.uuid4(), ppl_id: UUID.uuid4(), wf_id: UUID.uuid4(),
        jobs: [ctx.env_vars_job_1, ctx.env_vars_job_2]}
        |> Proto.deep_new!(ScheduleRequest)

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, %{task: task = %Task{}}} = TaskService.Stub.schedule(channel, request)

    task = task |> Proto.to_map!()
    assert {:ok, _} = UUID.info(task.id)
    assert task.state == :RUNNING
    assert task.result == :FAILED
    assert task.ppl_id == request.ppl_id
    assert task.wf_id == request.wf_id

    :timer.sleep(1000)
    {:ok, task} = Service.Task.get(task.id)
    assert Map.get(task, :state) == :FINISHED
    assert Map.get(task, :result) == :PASSED
  end

  test "gRPC schedule - prologue and epilogue make dirs and test checks their existance", ctx do
    request =
      %{request_token: UUID.uuid4(), ppl_id: UUID.uuid4(), wf_id: UUID.uuid4(),
        jobs: [ctx.prologue_job, ctx.epilogue_job]}
        |> Proto.deep_new!(ScheduleRequest)

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, %{task: task = %Task{}}} = TaskService.Stub.schedule(channel, request)

    task = task |> Proto.to_map!()
    assert {:ok, _} = UUID.info(task.id)
    assert task.state == :RUNNING
    assert task.result == :FAILED
    assert task.ppl_id == request.ppl_id
    assert task.wf_id == request.wf_id

    :timer.sleep(1000)
    {:ok, task} = Service.Task.get(task.id)
    assert Map.get(task, :state) == :FINISHED
    assert Map.get(task, :result) == :PASSED
    assert File.exists?("always")
    assert File.exists?("on_pass")
    refute File.exists?("on_fail")
  end

  test "gRPC schedule - task fails when one job's commmand fails", ctx do
    request =
      %{request_token: UUID.uuid4(), ppl_id: UUID.uuid4(), wf_id: UUID.uuid4(),
        jobs: [ctx.invalid_job]}
        |> Proto.deep_new!(ScheduleRequest)

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, %{task: task = %Task{}}} = TaskService.Stub.schedule(channel, request)

    task = task |> Proto.to_map!()
    assert {:ok, _} = UUID.info(task.id)
    assert task.state == :RUNNING
    assert task.result == :FAILED
    assert task.ppl_id == request.ppl_id
    assert task.wf_id == request.wf_id

    :timer.sleep(1000)
    {:ok, task} = Service.Task.get(task.id)
    assert Map.get(task, :state) == :FINISHED
    assert Map.get(task, :result) == :FAILED
  end

  test "gRPC schedule - raises INVALID_ARGUMENT error when request is invalid" do
    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:error, error = %GRPC.RPCError{}}
       = TaskService.Stub.schedule(channel, ScheduleRequest.new())
    assert GRPC.Status.invalid_argument == error.status
    assert error.message == "'jobs' List must have atleast one Job."
  end

  test "gRPC schedule - it is idempotent in regard to request_token", ctx do
    request =
      %{request_token: UUID.uuid4(), ppl_id: UUID.uuid4(), wf_id: UUID.uuid4(),
        jobs: [ctx.stop_job]}
        |> Proto.deep_new!(ScheduleRequest)

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, %{task: task_1 = %Task{}}} = TaskService.Stub.schedule(channel, request)
    assert {:ok, %{task: task_2 = %Task{}}} = TaskService.Stub.schedule(channel, request)
    assert task_1 |> Map.drop([:created_at, :finished_at])
           == task_2 |> Map.drop([:created_at, :finished_at])
  end

  # Describe

  test "gRPC describe - returns task description for valid task_id", ctx do
    request =
      %{request_token: UUID.uuid4(), ppl_id: UUID.uuid4(), wf_id: UUID.uuid4(),
        jobs: [ctx.stop_job]}
        |> Proto.deep_new!(ScheduleRequest)

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, %{task: task_1 = %Task{}}} = TaskService.Stub.schedule(channel, request)

    request = %{task_id: task_1.id} |> DescribeRequest.new()
    assert {:ok, %{task: task_2 = %Task{}}} = TaskService.Stub.describe(channel, request)
    assert task_1 |> Map.drop([:created_at, :finished_at])
           == task_2 |> Map.drop([:created_at, :finished_at])
  end

  test "gRPC describe - raises NOT_FOUND when task with given task_id is not found" do
    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    request = DescribeRequest.new(task_id: "not-found")

    assert {:error, error = %GRPC.RPCError{}}
       = TaskService.Stub.describe(channel, request)
    assert error.status  == GRPC.Status.not_found
    assert error.message == "'task_id' parameter that you provided doesn't match any task."
  end

  # DescribeMany

  test "gRPC describe_many - returns task description for valid task_id", ctx do
    request =
      %{request_token: UUID.uuid4(), ppl_id: UUID.uuid4(), wf_id: UUID.uuid4(),
        jobs: [ctx.stop_job]}
        |> Proto.deep_new!(ScheduleRequest)
    request_2 = %{request | request_token: UUID.uuid4()}

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, %{task: task_1 = %Task{}}} = TaskService.Stub.schedule(channel, request)
    assert {:ok, %{task: task_2 = %Task{}}} = TaskService.Stub.schedule(channel, request_2)

    request = %{task_ids: [task_1.id, task_2.id]} |> DescribeManyRequest.new()
    assert {:ok, %{tasks: [desc_1, desc_2]}} = TaskService.Stub.describe_many(channel, request)
    assert task_1 |> Map.drop([:created_at, :finished_at])
           == desc_1 |> Map.drop([:created_at, :finished_at])
    assert task_2 |> Map.drop([:created_at, :finished_at])
           == desc_2 |> Map.drop([:created_at, :finished_at])
  end

  test "gRPC describe_many - raises NOT_FOUND when task with given task_id is not found" do
    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    request = DescribeManyRequest.new(task_ids: ["not-found"])

    assert {:error, error = %GRPC.RPCError{}}
       = TaskService.Stub.describe_many(channel, request)
    assert error.status  == GRPC.Status.not_found
    assert error.message == "'task_id' parameter that you provided doesn't match any task."
  end

  # Terminate

  test "gRPC terminate - when called it stops running task", ctx do
    request =
      %{request_token: UUID.uuid4(), ppl_id: UUID.uuid4(), wf_id: UUID.uuid4(),
        jobs: [ctx.stop_job]}
        |> Proto.deep_new!(ScheduleRequest)

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    assert {:ok, %{task: task = %Task{}}} = TaskService.Stub.schedule(channel, request)

    request = TerminateRequest.new(task_id: task.id)

    {:ok, response} = TaskService.Stub.terminate(channel, request)
    assert response.message == "Task marked for termination."
    :timer.sleep(5000)

    assert {:ok, :FINISHED} = Service.Task.get_property(task.id, :state)
    assert {:ok, :STOPPED}  = Service.Task.get_property(task.id, :result)
  end

  test "gRPC terminate - raises NOT_FOUND when task with given task_id is not found" do
    assert {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    request = TerminateRequest.new(task_id: "not-found")

    assert {:error, error = %GRPC.RPCError{}}
       = TaskService.Stub.terminate(channel, request)
    assert error.status  == GRPC.Status.not_found
    assert error.message == "'task_id' parameter that you provided doesn't match any task."
  end
end
