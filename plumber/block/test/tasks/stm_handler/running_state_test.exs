defmodule Block.Tasks.STMHandler.RunningStateTest do
  @moduledoc """
  The running looper polls the task API for every running task. The task
  description (all jobs of the task) is written back only when it changed, so
  an unchanged poll does not rewrite a large jsonb value.
  """
  use ExUnit.Case
  import Ecto.Query
  import Mock

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.EctoRepo, as: Repo
  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient
  alias Block.Tasks.Model.Tasks
  alias Block.Tasks.STMHandler.RunningState

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Repo, "truncate table block_requests cascade;")

    request = %{
      ppl_id: UUID.uuid4(),
      pple_block_index: 0,
      request_args: %{"service" => "local"},
      version: "v3.0",
      definition: %{"build" => %{"jobs" => []}},
      hook_id: UUID.uuid4()
    }

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    {:ok, %{blk_req: blk_req}}
  end

  test "unchanged running description is not written again", ctx do
    task = stored_task(ctx.blk_req, description(:RUNNING, :ENQUEUED))

    assert transition(task, description(:RUNNING, :ENQUEUED)) == %{state: "running"}
  end

  test "changed running description is written", ctx do
    task = stored_task(ctx.blk_req, description(:RUNNING, :ENQUEUED))
    new_desc = description(:RUNNING, :STARTED)

    assert transition(task, new_desc) == %{state: "running", description: new_desc}
  end

  test "running description is written when nothing is stored yet", ctx do
    task = stored_task(ctx.blk_req, nil)
    new_desc = description(:RUNNING, :ENQUEUED)

    assert transition(task, new_desc) == %{state: "running", description: new_desc}
  end

  test "done task always writes its description", ctx do
    desc = description(:FINISHED, :FINISHED, :PASSED)
    task = stored_task(ctx.blk_req, desc)

    assert transition(task, desc) == %{state: "done", description: desc, result: "passed"}
  end

  test "failed task always writes its description", ctx do
    desc = description(:FINISHED, :FINISHED, :FAILED)
    task = stored_task(ctx.blk_req, desc)

    assert transition(task, desc) ==
             %{state: "done", description: desc, result: "failed", result_reason: "test"}
  end

  test "skipping the write keeps the stored description", ctx do
    stored = description(:RUNNING, :ENQUEUED)
    task = stored_task(ctx.blk_req, stored)

    update = transition(task, stored)
    {1, _} = from(t in Tasks, where: t.id == ^task.id) |> Repo.update_all(set: Map.to_list(update))

    assert Repo.get(Tasks, task.id).description == json(stored)
  end

  test "same_description?/2 compares in JSON form" do
    desc = description(:RUNNING, :STARTED)

    assert RunningState.same_description?(desc, json(desc))
    refute RunningState.same_description?(desc, nil)
    refute RunningState.same_description?(desc, json(description(:RUNNING, :ENQUEUED)))
    refute RunningState.same_description?(%{bad: {:not, :json}}, %{})
  end

  test "same_description?/2 agrees with a JSON round trip" do
    base = description(:RUNNING, :STARTED)
    stored = json(base)
    ts = ~U[2026-11-04 10:00:00.123456Z]

    same = [
      base,
      %{a: nil, b: true, c: false, d: 1, e: 1.5, f: "x", g: :ATOM, h: [], i: %{}},
      %{"string_key" => [%{nested: [ts, :invalid_datetime]}]}
    ]

    Enum.each(same, fn desc -> assert RunningState.same_description?(desc, json(desc)) end)

    changed = [
      put_in(base, [:task, :state], :FINISHED),
      update_in(base, [:task, :jobs], &tl/1),
      update_in(base, [:task, :jobs], &(&1 ++ [hd(&1)])),
      put_in(base, [:task, :extra], nil),
      update_in(base, [:task], &Map.delete(&1, :finished_at)),
      put_in(base, [:task, :created_at], DateTime.add(ts, 1, :microsecond)),
      put_in(base, [:status, :message], "different")
    ]

    Enum.each(changed, fn desc -> refute RunningState.same_description?(desc, stored) end)

    refute RunningState.same_description?(%{n: 1}, %{"n" => 1.0})
    refute RunningState.same_description?(%{n: nil}, %{"n" => "nil"})
    refute RunningState.same_description?(%{n: true}, %{"n" => "true"})
    refute RunningState.same_description?(%{d: ~N[2026-11-04 10:00:00]}, %{"d" => "2026-11-04T10:00:00"})
  end

  # Runs the real scheduling_handler/1 with the task API describe stubbed and
  # returns the fields the task would be updated with.
  defp transition(task, new_desc) do
    with_mock TaskApiClient, describe: fn _task_id, _url -> {:ok, new_desc} end do
      assert {:ok, exit_fun} = RunningState.scheduling_handler(task)
      assert {:ok, update} = exit_fun.(nil, nil)
      update
    end
  end

  # Inserts the task and reads it back, so the description has the shape the
  # looper sees after its claim query (jsonb decoded with string keys).
  defp stored_task(blk_req, desc) do
    {:ok, task} =
      %Tasks{}
      |> Tasks.changeset(%{
        block_id: blk_req.id,
        state: "running",
        in_scheduling: false,
        build_request_id: UUID.uuid4(),
        task_id: UUID.uuid4(),
        description: desc
      })
      |> Repo.insert()

    Repo.get(Tasks, task.id)
  end

  defp json(term), do: term |> Jason.encode!() |> Jason.decode!()

  defp description(task_state, job_state, result \\ :RESULT_UNSPECIFIED) do
    started = ~U[2026-11-04 10:00:00.123456Z]

    jobs =
      for index <- 0..2 do
        %{
          id: "job-#{index}",
          name: "job #{index}",
          index: index,
          state: job_state,
          result: result,
          enqueued_at: started,
          started_at: if(job_state == :ENQUEUED, do: :invalid_datetime, else: started),
          finished_at: :invalid_datetime
        }
      end

    %{
      status: %{code: :OK, message: ""},
      task: %{
        id: "task-1",
        state: task_state,
        result: result,
        jobs: jobs,
        created_at: started,
        finished_at: :invalid_datetime
      }
    }
  end
end
