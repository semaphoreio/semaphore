defmodule Ppl.AfterPplTasks.STMHandler.TerminateTest do
  use ExUnit.Case, async: false

  import Mock

  alias Ppl.AfterPplTasks.Model.AfterPplTasks
  alias Ppl.AfterPplTasks.STMHandler.{PendingState, RunningState, WaitingState}
  alias Ppl.TaskClient

  describe "AfterPplTasks.changeset/2" do
    test "accepts a terminate request" do
      for request <- ["stop", "cancel"] do
        changeset =
          AfterPplTasks.changeset(%AfterPplTasks{}, %{
            ppl_id: UUID.uuid4(),
            state: "running",
            in_scheduling: false,
            terminate_request: request,
            terminate_request_desc: "API call"
          })

        assert changeset.valid?, "expected #{request} to be a valid terminate request"
      end
    end

    test "rejects an unknown terminate request" do
      changeset =
        AfterPplTasks.changeset(%AfterPplTasks{}, %{
          ppl_id: UUID.uuid4(),
          state: "running",
          in_scheduling: false,
          terminate_request: "explode"
        })

      refute changeset.valid?
    end
  end

  describe "terminate_request_handler/2 before the task is scheduled" do
    test "waiting task is stopped without ever starting" do
      assert {:ok, exit_fun} = WaitingState.terminate_request_handler(after_ppl_task(), "stop")
      assert {:ok, %{state: "done", result: "stopped"}} = exit_fun.(nil, nil)
    end

    test "pending task is stopped without ever starting" do
      assert {:ok, exit_fun} = PendingState.terminate_request_handler(after_ppl_task(), "stop")
      assert {:ok, %{state: "done", result: "stopped"}} = exit_fun.(nil, nil)
    end

    test "an unrelated terminate request falls through to the scheduling handler" do
      assert {:ok, :continue} = WaitingState.terminate_request_handler(after_ppl_task(), "")
      assert {:ok, :continue} = PendingState.terminate_request_handler(after_ppl_task(), "")
    end
  end

  describe "terminate_request_handler/2 while the task is running" do
    test "asks the task API to terminate and stays running until it winds down" do
      with_mock TaskClient,
        describe: fn _id -> {:ok, "running", ""} end,
        terminate: fn _id -> {:ok, "termination started"} end do
        assert {:ok, exit_fun} = RunningState.terminate_request_handler(after_ppl_task(), "stop")
        assert {:ok, %{state: "running"}} = exit_fun.(nil, nil)

        assert_called(TaskClient.terminate("after-task-1"))
      end
    end

    test "records the task's own verdict once it is done" do
      with_mock TaskClient,
        describe: fn _id -> {:ok, "done", "stopped"} end,
        terminate: fn _id -> {:ok, "termination started"} end do
        assert {:ok, exit_fun} = RunningState.terminate_request_handler(after_ppl_task(), "stop")
        assert {:ok, %{state: "done", result: "stopped"}} = exit_fun.(nil, nil)

        refute called(TaskClient.terminate(:_))
      end
    end

    test "a task that finished on its own keeps its real result" do
      with_mock TaskClient,
        describe: fn _id -> {:ok, "done", "passed"} end,
        terminate: fn _id -> {:ok, "termination started"} end do
        assert {:ok, exit_fun} = RunningState.terminate_request_handler(after_ppl_task(), "stop")
        assert {:ok, %{state: "done", result: "passed"}} = exit_fun.(nil, nil)
      end
    end

    test "surfaces an error from the task API instead of losing the request" do
      with_mock TaskClient,
        describe: fn _id -> {:error, "task api down"} end,
        terminate: fn _id -> {:ok, "termination started"} end do
        assert {:ok, exit_fun} = RunningState.terminate_request_handler(after_ppl_task(), "stop")
        assert {:error, %{error_description: description}} = exit_fun.(nil, nil)
        assert description =~ "task api down"
      end
    end
  end

  defp after_ppl_task do
    %{ppl_id: UUID.uuid4(), after_task_id: "after-task-1", state: "running"}
  end
end
