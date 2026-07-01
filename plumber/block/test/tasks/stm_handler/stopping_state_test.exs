defmodule Block.Tasks.STMHandler.StoppingStateTest do
  @moduledoc """
  Unit tests for how a task that is being stopped resolves its final result.

  If the jobs actually finished (passed/failed) before the stop took effect, that verdict
  must be preserved instead of being overwritten with "stopped" — otherwise the block above
  is relabelled and re-run on a partial rebuild.
  """
  use ExUnit.Case
  import Mock

  alias Block.Tasks.STMHandler.StoppingState
  alias Block.TaskApiClient.GrpcClient, as: TaskApiClient

  # Runs the real scheduling_handler/1 with the task-api describe response stubbed, and
  # returns the state map the task would be persisted with (the raw description is dropped
  # from the assertion for readability).
  defp resolve(zebra_state, zebra_result, task) do
    description = %{task: %{state: zebra_state, result: zebra_result}}

    with_mock TaskApiClient, [describe: fn _task_id, _url -> {:ok, description} end] do
      assert {:ok, transition} = StoppingState.scheduling_handler(task)
      assert {:ok, result} = transition.(nil, nil)
      Map.delete(result, :description)
    end
  end

  @task %{task_id: "task-1", terminate_request_desc: "API call"}

  test "a task that finished passed before the stop is kept as passed (#10010)" do
    assert resolve(:FINISHED, :PASSED, @task) == %{state: "done", result: "passed"}
  end

  test "a task that finished failed is kept as failed" do
    assert resolve(:FINISHED, :FAILED, @task) ==
             %{state: "done", result: "failed", result_reason: "test"}
  end

  test "a task that was actually stopped is recorded stopped" do
    assert resolve(:FINISHED, :STOPPED, @task) ==
             %{state: "done", result: "stopped", result_reason: "user"}
  end

  test "while the task has not finished the task stays in stopping" do
    assert resolve(:STOPPING, :RESULT_UNSPECIFIED, @task) == %{state: "stopping"}
  end
end
