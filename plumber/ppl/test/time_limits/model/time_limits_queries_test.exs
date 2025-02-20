defmodule Ppl.TimeLimits.Model.TimeLimitsQueries.Test do
  use ExUnit.Case
  doctest Ppl.TimeLimits.Model.TimeLimitsQueries

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.TimeLimits.Model.TimeLimitsQueries

  setup do
    Test.Helpers.truncate_db()

    request_args = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    {:ok, ppl} = PplsQueries.insert(ppl_req)

    {:ok, %{ppl: ppl}}
  end


  test "set_time_limit for a pipeline succedes when time limit is not pre-existing", ctx do
    ppl = Map.merge(ctx.ppl, %{exec_time_limit_min: 15})

    timestamp = DateTime.utc_now()

    assert {:ok, tl} = TimeLimitsQueries.set_time_limit(ppl, "pipeline")
    assert tl.ppl_id == ppl.ppl_id
    assert tl.type == "pipeline"
    assert tl.block_index == -1
    assert tl.state == "tracking"

    assert DateTime.diff(tl.deadline, timestamp, :second) >= 15 * 60
  end

  test "insert time_limit for a ppl block succedes when time limit is not pre-existing", ctx do
    ppl_block = Map.merge(ctx.ppl, %{exec_time_limit_min: 15, block_index: 0})

    timestamp = DateTime.utc_now()

    assert {:ok, tl} = TimeLimitsQueries.set_time_limit(ppl_block, "ppl_block")
    assert tl.ppl_id == ppl_block.ppl_id
    assert tl.type == "ppl_block"
    assert tl.block_index == 0
    assert tl.state == "tracking"

    assert DateTime.diff(tl.deadline, timestamp, :second) >= 15 * 60
  end

  test "when time limit already exists => set_time_limit will only update the deadline", ctx do
    ppl = Map.merge(ctx.ppl, %{exec_time_limit_min: 15})

    timestamp = DateTime.utc_now()

    assert {:ok, tl} = TimeLimitsQueries.set_time_limit(ppl, "pipeline")
    assert tl.ppl_id == ppl.ppl_id
    assert tl.type == "pipeline"
    assert tl.block_index == -1
    assert tl.state == "tracking"
    assert DateTime.diff(tl.deadline, timestamp, :second) >= 15 * 60

    :timer.sleep(2_000)

    assert {:ok, tl2} = TimeLimitsQueries.set_time_limit(ppl, "pipeline")
    assert tl2.ppl_id == ppl.ppl_id
    assert tl2.type == "pipeline"
    assert tl2.block_index == -1
    assert tl2.state == "tracking"
    assert DateTime.diff(tl2.deadline, timestamp, :second) >= 15 * 60 + 2
    assert DateTime.diff(tl2.deadline, tl.deadline, :second) >= 2
  end
end
