defmodule Ppl.PplBlocks.STMHandler.StoppingStateTest do
  @moduledoc """
  Unit tests for how a pipeline block that is being stopped resolves its final result.

  When a block is force-stopped (e.g. fast_failing of a sibling block) but the underlying
  block had already finished, the real verdict must be preserved. Otherwise a partial
  rebuild — which only reuses blocks whose result is "passed" — needlessly re-runs.
  """
  use ExUnit.Case
  import Mock

  alias Ppl.PplBlocks.STMHandler.StoppingState

  # Runs the real scheduling_handler/1 with Block.status/1 stubbed to the given block status,
  # and returns the state map the ppl-block would be persisted with.
  defp resolve(block_status, ppl_blk) do
    with_mock Block, [status: fn _block_id -> {:ok, block_status} end] do
      assert {:ok, transition} = StoppingState.scheduling_handler(ppl_blk)
      assert {:ok, result} = transition.(nil, nil)
      result
    end
  end

  @fast_failing %{block_id: "blk-1", terminate_request_desc: "fast_failing"}

  test "a block that already passed is kept as passed, not relabelled stopped (#10010)" do
    status = %{state: "done", result: "passed", result_reason: nil}
    assert resolve(status, @fast_failing) == %{state: "done", result: "passed"}
  end

  test "a block that already failed is kept as failed" do
    status = %{state: "done", result: "failed", result_reason: "test"}

    assert resolve(status, @fast_failing) ==
             %{state: "done", result: "failed", result_reason: "test"}
  end

  test "a genuinely stopped block is recorded stopped with the fast_failing reason" do
    status = %{state: "done", result: "stopped", result_reason: "internal"}

    assert resolve(status, @fast_failing) ==
             %{state: "done", result: "stopped", result_reason: "fast_failing"}
  end

  test "a canceled block is recorded stopped (only real verdicts are preserved)" do
    status = %{state: "done", result: "canceled", result_reason: "internal"}

    assert resolve(status, @fast_failing) ==
             %{state: "done", result: "stopped", result_reason: "fast_failing"}
  end

  test "a user-initiated stop keeps the user reason" do
    ppl_blk = %{block_id: "blk-1", terminate_request_desc: "API call"}
    status = %{state: "done", result: "stopped", result_reason: "internal"}

    assert resolve(status, ppl_blk) ==
             %{state: "done", result: "stopped", result_reason: "user"}
  end

  test "while the block is not done yet the ppl-block stays in stopping" do
    status = %{state: "running", result: nil, result_reason: nil}
    assert resolve(status, @fast_failing) == %{state: "stopping"}
  end
end
