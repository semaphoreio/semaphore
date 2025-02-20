defmodule Block.Looper.Tasks.TaskScheduleRequest.Test do
  use ExUnit.Case, async: false

  import Mock
  import Ecto.Query

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Blocks.Model.BlocksQueries
  alias Block.Tasks.Model.Tasks
  alias Block.EctoRepo, as: Repo
  alias Test.Helpers
  alias InternalApi.Task.{TaskService, ScheduleResponse}
  alias Block.Tasks.STMHandler.PendingState
  alias Block.Tasks.Model.TasksQueries
  alias Util.Proto


  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    request_args =
      %{"service" => "local", "repo_name" => "2_basic", "ppl_fail_fast" => "cancel",
         "label" => "master", "project_id" => UUID.uuid4, "wf_id" => UUID.uuid4,
         "organization_id" => UUID.uuid4, "hook_id" => UUID.uuid4, "ppl_priority" => 50,
         "working_dir" => "/.semaphore", "commit_sha" => "sha123", "commit_range" => "1..2",
         "file_name" => "semaphore.yml", "repository_id" => "repo_1", "deployment_target_id" => "dt_1"}
    source_args = %{"git_ref_type" => "branch"}
    job   = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"jobs" => [job], "agent" => agent}
    definition = %{"name" => "Block 1", "build" => build}

    {:ok, %{request_args: request_args, definition: definition, source_args: source_args}}
  end

  @tag :integration
  test "valid schedule request with priority defined on job level", ctx do
    priority = [%{"value" => 57, "when" => "branch = 'dev'"},
                %{"value" => 85, "when" => "branch = 'master'"}]
    job = %{"name" => "job1", "commands" => ["echo foo", "echo bar"], "priority" => priority}
    definition = ctx.definition |> put_in(["build", "jobs"], [job])


    params = [UUID.uuid4(), 0, ctx.request_args, UUID.uuid4(), "v1.0",
              definition, ctx.source_args]
              |> form_request()
              |> Map.put(:expected_ff, :CANCEL)
              |> Map.put(:priority, 85)

    assert {:ok, block_id} = Block.schedule(params)

    loopers = start_needed_loopers()

    assert block = Test.Helpers.wait_for_block_state(block_id, "running", 3_000)

    with_mock TaskService.Stub, [schedule: &(mocked_schedule(&1, &2, &3, params))] do
      loopers = loopers |> Enum.concat([PendingState.start_link()])

      :timer.sleep(3_000)

      stop_loopers(loopers)
    end

    assert {:ok, %{state: "running"}} = TasksQueries.get_by_id(block_id)
  end

  @tag :integration
  test "when multiple job priority conditions are true, first one is used", ctx do
    priority = [%{"value" => 57, "when" => "branch = 'dev'"},
                %{"value" => 85, "when" => "branch = 'master'"},
                %{"value" => 18, "when" => true}]
    job = %{"name" => "job1", "commands" => ["echo foo", "echo bar"], "priority" => priority}
    definition = ctx.definition |> put_in(["build", "jobs"], [job])


    params = [UUID.uuid4(), 0, ctx.request_args, UUID.uuid4(), "v1.0",
              definition, ctx.source_args]
              |> form_request()
              |> Map.put(:expected_ff, :CANCEL)
              |> Map.put(:priority, 85)

    assert {:ok, block_id} = Block.schedule(params)

    loopers = start_needed_loopers()

    assert block = Test.Helpers.wait_for_block_state(block_id, "running", 3_000)

    with_mock TaskService.Stub, [schedule: &(mocked_schedule(&1, &2, &3, params))] do
      loopers = loopers |> Enum.concat([PendingState.start_link()])

      :timer.sleep(3_000)

      stop_loopers(loopers)
    end

    assert {:ok, %{state: "running"}} = TasksQueries.get_by_id(block_id)
  end

  @tag :integration
  test "valid schedule request where not one of job level priority conds is met", ctx do
    priority = [%{"value" => 1, "when" => "branch = 'dev'"},
                %{"value" => 2, "when" => "branch = 'test'"},
                %{"value" => 3, "when" => "tag =~ '.*'"}]
    job = %{"name" => "job1", "commands" => ["echo foo", "echo bar"], "priority" => priority}
    definition = ctx.definition |> put_in(["build", "jobs"], [job])


    params = [UUID.uuid4(), 0, ctx.request_args, UUID.uuid4(), "v1.0",
              definition, ctx.source_args]
              |> form_request()
              |> Map.put(:expected_ff, :CANCEL)
              |> Map.put(:priority, 50)

    assert {:ok, block_id} = Block.schedule(params)

    loopers = start_needed_loopers()

    assert block = Test.Helpers.wait_for_block_state(block_id, "running", 3_000)

    with_mock TaskService.Stub, [schedule: &(mocked_schedule(&1, &2, &3, params))] do
      loopers = loopers |> Enum.concat([PendingState.start_link()])

      :timer.sleep(3_000)

      stop_loopers(loopers)
    end

    assert {:ok, %{state: "running"}} = TasksQueries.get_by_id(block_id)
  end

  @tag :integration
  test "block is malformed if one of when conditions in job priority list is malformed", ctx do
    priority = [%{"value" => 1, "when" => "change_in(123)"}]
    job = %{"name" => "job1", "commands" => ["echo foo", "echo bar"], "priority" => priority}
    definition = ctx.definition |> put_in(["build", "jobs"], [job])

    params = [UUID.uuid4(), 0, ctx.request_args, UUID.uuid4(), "v1.0",
              definition, ctx.source_args]
              |> form_request()
              |> Map.put(:expected_ff, :CANCEL)
              |> Map.put(:priority, 50)

    assert {:ok, block_id} = Block.schedule(params)

    loopers = start_needed_loopers() |> Enum.concat([PendingState.start_link()])

    assert block = Test.Helpers.wait_for_block_state(block_id, "done", 6_000)

    stop_loopers(loopers)

    assert {:ok, %{state: "done", result: "failed", result_reason: "malformed"}}
            = BlocksQueries.get_by_id(block_id)
  end

  @tag :integration
  test "valid schedule request with containers instead of agent", ctx do
    containers = [
      %{"name" => "main", "image" => "semaphoreci/test-image"},
      %{"name" => "db", "image" => "postgres", "command" => "/bin/bash",
        "env_vars" => [%{"name" => "PG_PASSWORD", "value" => "123"}],
        "secrets" => [%{"name" => "postgres-url"}], "user" => "postgres",
        "entrypoint" => "some test commands"},
    ]

    agent = %{"containers" => containers}
            |> Map.merge(ctx.definition |> get_in(["build", "agent"]))

    definition = ctx.definition |> put_in(["build", "agent"], agent)

    params = [UUID.uuid4(), 0, ctx.request_args, UUID.uuid4(), "v1.0",
              definition, ctx.source_args]
              |> form_request(0, true)
              |> Map.put(:expected_ff, :CANCEL)
              |> Map.put(:priority, 50)

    assert {:ok, block_id} = Block.schedule(params)

    loopers = start_needed_loopers()

    assert block = Test.Helpers.wait_for_block_state(block_id, "running", 3_000)

    with_mock TaskService.Stub, [schedule: &(mocked_schedule(&1, &2, &3, params))] do
      loopers = loopers |> Enum.concat([PendingState.start_link()])

      :timer.sleep(3_000)

      stop_loopers(loopers)
    end

    assert {:ok, %{state: "running"}} = TasksQueries.get_by_id(block_id)
  end

  @tag :integration
  test "valid schedule request with execution_time_limit on job level", ctx do
    job = %{"name" => "job1", "commands" => ["echo foo", "echo bar"],
            "execution_time_limit" => %{"minutes" => 45, "hours" => 1}}
    definition = ctx.definition |> put_in(["build", "jobs"], [job])

    params = [UUID.uuid4(), 0, ctx.request_args, UUID.uuid4(), "v1.0", definition,
              ctx.source_args]
             |> form_request()
             |> Map.put(:expected_ff, :CANCEL)
             |> Map.put(:time_limit, 105)
             |> Map.put(:priority, 50)


    assert {:ok, block_id} = Block.schedule(params)

    loopers = start_needed_loopers()

    assert block = Test.Helpers.wait_for_block_state(block_id, "running", 3_000)


    with_mock TaskService.Stub, [schedule: &(mocked_schedule(&1, &2, &3, params))] do
      loopers = loopers |> Enum.concat([PendingState.start_link()])

      :timer.sleep(3_000)

      stop_loopers(loopers)
    end

    assert {:ok, %{state: "running"}} = TasksQueries.get_by_id(block_id)
  end

  @tag :integration
  test "valid schedule request for fail-fast only set on pipeline level", ctx do
    test_fail_fast_set_properly(ctx.request_args, ctx.source_args, ctx.definition, :CANCEL)
  end

  @tag :integration
  test "valid schedule request for matching fail-fast on task level which overrides one on pipeline level", ctx do
    definition =
      ctx.definition
      |> put_in(["build", "fail_fast"], %{"stop" => %{"when" => "branch = 'master'"}})

    test_fail_fast_set_properly(ctx.request_args, ctx.source_args, definition, :STOP)
  end

  @tag :integration
  test "valid schedule request for when fail-fast condition on task level does not match", ctx do
    definition =
      ctx.definition
      |> put_in(["build", "fail_fast"], %{"stop" => %{"when" => "branch = 'master'"}})

    request_args = ctx.request_args |> Map.put("label", "not-master")

    test_fail_fast_set_properly(request_args, ctx.source_args, definition, :CANCEL)
  end

  @tag :integration
  test "valid schedule request when no fail-fast is set anywhere", ctx do
    request_args = ctx.request_args |> Map.delete("ppl_fail_fast")
    test_fail_fast_set_properly(request_args, ctx.source_args, ctx.definition, :NONE)
  end

  defp test_fail_fast_set_properly(request_args, source_args, definition, expected_ff) do
    params = [UUID.uuid4(), 0, request_args, UUID.uuid4(), "v1.0", definition, source_args]
             |> form_request()

    assert {:ok, block_id} = Block.schedule(params)

    loopers = start_needed_loopers()

    assert block = Test.Helpers.wait_for_block_state(block_id, "running", 3_000)

    params = params |> Map.put(:expected_ff, expected_ff) |> Map.put(:priority, 50)

    with_mock TaskService.Stub, [schedule: &(mocked_schedule(&1, &2, &3, params))] do
      loopers = loopers |> Enum.concat([PendingState.start_link()])

      :timer.sleep(3_000)

      stop_loopers(loopers)
    end

    assert {:ok, %{state: "running"}} = TasksQueries.get_by_id(block_id)
  end

  defp mocked_schedule(_channel, request, _opts, params) do
    expected = expected_request(params)
    assert expected == request |> Proto.to_map!() |> Map.drop([:request_token])

    %{task: %{id: UUID.uuid4(), created_at: %{seconds: 123455, nanos: 23434}}}
    |> Proto.deep_new(ScheduleResponse)
  end

  defp expected_request(params) do
    %{fail_fast: params.expected_ff,
      jobs: [
          %{
            agent: %{
              containers: containers(params.containers?),
              image_pull_secrets: [],
              machine: %{
                os_image: "ubuntu1804",
                type: "e1-standard-2"
              }
            },
            commands: ["echo foo", "echo bar"],
            env_vars: [],
            epilogue_always_cmds: [],
            epilogue_on_fail_cmds: [],
            epilogue_on_pass_cmds: [],
            name: "job1",
            prologue_commands: [],
            secrets: [],
            execution_time_limit: params.time_limit,
            priority: params.priority
          }
        ],
      org_id: params.request_args["organization_id"],
      ppl_id: params.ppl_id,
      project_id: params.request_args["project_id"],
      wf_id: params.request_args["wf_id"],
      hook_id:  params.request_args["hook_id"],
      repository_id:  params.request_args["repository_id"],
      deployment_target_id: params.request_args["deployment_target_id"]
    }
  end

  defp containers(false), do: []
  defp containers(true) do
    [
      %{command: "", entrypoint: "", env_vars: [], image: "semaphoreci/test-image",
       name: "main", secrets: [], user: ""},

      %{command: "/bin/bash", entrypoint: "some test commands",
        env_vars: [%{name: "PG_PASSWORD", value: "123"}], image: "postgres",
        name: "db", secrets: [%{name: "postgres-url"}], user: "postgres"}
    ]
  end

  defp form_request(
    [ppl_id, pple_block_index, request_args, hook_id, version,
     definition, source_args], time_limit \\ 0, containers? \\ false) do
    %{
      ppl_id: ppl_id, pple_block_index: pple_block_index, version: version,
      hook_id: hook_id, request_args: request_args, definition: definition,
      source_args: source_args, time_limit: time_limit, containers?: containers?,
    }
  end

  def start_needed_loopers() do
    []
    # Blocks Loopers
    |> Enum.concat([Block.Blocks.STMHandler.InitializingState.start_link()])
    |> Enum.concat([Block.Blocks.STMHandler.RunningState.start_link()])
  end

  def stop_loopers(loopers) do
    loopers |> Enum.map(fn({_resp, pid}) -> GenServer.stop(pid) end)
  end
end
