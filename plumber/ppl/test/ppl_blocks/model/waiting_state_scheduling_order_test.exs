defmodule Ppl.PplBlocks.Model.WaitingStateSchedulingOrderTest do
  use ExUnit.Case

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplBlocks.Model.{PplBlocks, WaitingStateScheduling}

  import Ecto.Query

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "claims the least recently updated ready block first" do
    ppl_id = running_pipeline()
    [b0, b1, b2] = insert_blocks(ppl_id, 3)

    set_updated_at(b0, ~N[2026-01-01 10:00:00.000000])
    set_updated_at(b1, ~N[2026-01-01 08:00:00.000000])
    set_updated_at(b2, ~N[2026-01-01 09:00:00.000000])

    assert claimed_id() == b1.id
    assert claimed_id() == b2.id
    assert claimed_id() == b0.id
    assert {:ok, []} = WaitingStateScheduling.get_ready_block()
  end

  test "orders by age across pipelines" do
    ppl_a = running_pipeline()
    ppl_b = running_pipeline()
    [a0] = insert_blocks(ppl_a, 1)
    [b0] = insert_blocks(ppl_b, 1)

    set_updated_at(a0, ~N[2026-01-01 10:00:00.000000])
    set_updated_at(b0, ~N[2026-01-01 09:00:00.000000])

    assert claimed_id() == b0.id
    assert claimed_id() == a0.id
  end

  test "claims blocks with a terminate request before older ready blocks" do
    ppl_id = running_pipeline()
    [old_ready, new_ready, stopped] = insert_blocks(ppl_id, 3)

    set_updated_at(old_ready, ~N[2026-01-01 08:00:00.000000])
    set_updated_at(new_ready, ~N[2026-01-01 09:00:00.000000])
    set_updated_at(stopped, ~N[2026-01-01 10:00:00.000000])
    set_terminate_request(stopped, "stop")

    assert {:ok, [{_old, claimed}]} = WaitingStateScheduling.get_ready_block()
    assert claimed.id == stopped.id
    assert claimed.terminate_request == "stop"

    assert claimed_id() == old_ready.id
    assert claimed_id() == new_ready.id
  end

  test "orders terminate requests oldest first" do
    ppl_id = running_pipeline()
    [t0, t1] = insert_blocks(ppl_id, 2)

    set_updated_at(t0, ~N[2026-01-01 10:00:00.000000])
    set_updated_at(t1, ~N[2026-01-01 09:00:00.000000])
    set_terminate_request(t0, "cancel")
    set_terminate_request(t1, "stop")

    assert claimed_id() == t1.id
    assert claimed_id() == t0.id
  end

  test "claims terminate requests of blocks whose pipeline is not running" do
    ppl_id = running_pipeline()
    [blk] = insert_blocks(ppl_id, 1)
    set_terminate_request(blk, "stop")
    "update pipelines set state = 'stopping';" |> Repo.query!()

    assert claimed_id() == blk.id
  end

  test "does not claim ready blocks of a pipeline that is not running" do
    ppl_id = running_pipeline()
    insert_blocks(ppl_id, 2)
    "update pipelines set state = 'stopping';" |> Repo.query!()

    assert {:ok, []} = WaitingStateScheduling.get_ready_block()
  end

  test "does not claim a block that is already in scheduling" do
    ppl_id = running_pipeline()
    [b0, b1] = insert_blocks(ppl_id, 2)

    set_updated_at(b0, ~N[2026-01-01 08:00:00.000000])
    set_updated_at(b1, ~N[2026-01-01 09:00:00.000000])

    assert claimed_id() == b0.id
    assert claimed_id() == b1.id
    assert {:ok, []} = WaitingStateScheduling.get_ready_block()
  end

  test "a block locked by an open claim is skipped by a concurrent claim" do
    ppl_id = running_pipeline()
    [b0, b1] = insert_blocks(ppl_id, 2)
    set_updated_at(b0, ~N[2026-01-01 08:00:00.000000])
    set_updated_at(b1, ~N[2026-01-01 09:00:00.000000])

    parent = self()

    holder =
      Task.async(fn ->
        Repo.transaction(fn ->
          {:ok, [{_, blk}]} = WaitingStateScheduling.do_get_ready_block()
          send(parent, {:claimed, blk.id})

          receive do
            :release -> blk.id
          after
            5_000 -> blk.id
          end
        end)
      end)

    assert_receive {:claimed, held_id}, 5_000
    assert held_id == b0.id

    # The oldest block is row-locked by the open transaction above.
    assert claimed_id() == b1.id

    send(holder.pid, :release)
    assert {:ok, ^held_id} = Task.await(holder)

    assert {:ok, []} = WaitingStateScheduling.get_ready_block()
  end

  test "concurrent claimers never claim the same block twice" do
    ppl_ids = for _ <- 1..4, do: running_pipeline()
    blocks = ppl_ids |> Enum.flat_map(&insert_blocks(&1, 10))

    claimed =
      1..2
      |> Enum.map(fn _ -> Task.async(fn -> claim_all([]) end) end)
      |> Enum.flat_map(&Task.await(&1, 30_000))

    assert length(claimed) == length(blocks)
    assert Enum.uniq(claimed) == claimed
    assert MapSet.new(claimed) == MapSet.new(blocks, & &1.id)
  end

  test ":ready_first claims a ready block before an older terminate request" do
    stopping_ppl = running_pipeline()
    [stopped] = insert_blocks(stopping_ppl, 1)
    ready_ppl = running_pipeline()
    [ready] = insert_blocks(ready_ppl, 1)
    # Only the stopped block's pipeline leaves running, so the stopped block
    # is not in the ready group and only the terminate group can claim it.
    "update pipelines set state = 'stopping' where ppl_id = $1;"
    |> Repo.query!([Ecto.UUID.dump!(stopping_ppl)])

    set_updated_at(stopped, ~N[2026-01-01 08:00:00.000000])
    set_updated_at(ready, ~N[2026-01-01 09:00:00.000000])
    set_terminate_request(stopped, "stop")

    assert {:ok, [{_, blk}]} = WaitingStateScheduling.get_ready_block(:ready_first)
    assert blk.id == ready.id
  end

  test ":ready_first falls back to terminate requests when nothing is ready" do
    ppl_id = running_pipeline()
    [stopped] = insert_blocks(ppl_id, 1)
    set_terminate_request(stopped, "stop")
    "update pipelines set state = 'stopping';" |> Repo.query!()

    assert {:ok, [{_, blk}]} = WaitingStateScheduling.get_ready_block(:ready_first)
    assert blk.id == stopped.id
  end

  test "a backlog of stops does not starve ready blocks within a batch" do
    stopping = running_pipeline()
    stopped = insert_blocks(stopping, 10)
    Enum.each(stopped, &set_terminate_request(&1, "stop"))

    ready_ppl = running_pipeline()
    ready = insert_blocks(ready_ppl, 2)
    # The stopped blocks are also "ready" (their pipeline is running), so make
    # the real ready blocks the oldest ones in the ready group.
    Enum.each(ready, &set_updated_at(&1, ~N[2026-01-01 08:00:00.000000]))

    # One wake-up of the waiting STM with batch_size 5.
    claimed =
      for batch_index <- 0..4 do
        order = Ppl.PplBlocks.STMHandler.WaitingState.claim_order(batch_index)
        {:ok, [{_, blk}]} = WaitingStateScheduling.get_ready_block(order)
        blk.id
      end

    ready_ids = MapSet.new(ready, & &1.id)
    assert claimed |> Enum.filter(&MapSet.member?(ready_ids, &1)) |> length() == 2
    assert claimed |> Enum.reject(&MapSet.member?(ready_ids, &1)) |> length() == 3
    # Stops still go first.
    refute MapSet.member?(ready_ids, hd(claimed))
  end

  test "claim_order alternates terminate-first and ready-first" do
    alias Ppl.PplBlocks.STMHandler.WaitingState

    assert Enum.map(0..4, &WaitingState.claim_order/1) ==
             [:terminate_first, :ready_first, :terminate_first, :ready_first, :terminate_first]
  end

  # Joined in FROM, the claim subquery can be rescanned once per outer row of
  # a nested loop (each rescan skips the rows already locked and claims one
  # more). Which plan the planner picks depends on table stats, so check the
  # shape instead: the claim must be an InitPlan, which runs exactly once.
  test "the claim subquery runs once per statement (InitPlan)" do
    claim =
      "SELECT pb.* FROM pipeline_blocks AS pb ORDER BY pb.updated_at LIMIT 1 FOR UPDATE OF pb SKIP LOCKED"

    %{rows: [[[%{"Plan" => plan}]]]} =
      ("EXPLAIN (FORMAT JSON) " <> WaitingStateScheduling.ready_ppl_block_update_query(claim))
      |> Repo.query!([NaiveDateTime.utc_now()])

    # One entry per LockRows node: whether it sits under an InitPlan.
    lock_nodes = lock_rows_nodes(plan, false)

    assert lock_nodes != []
    assert Enum.all?(lock_nodes)
  end

  for order <- [:terminate_first, :ready_first] do
    test "a #{order} claim takes exactly one block when several are claimable" do
      ppl_id = running_pipeline()
      stopped = insert_blocks(ppl_id, 3)
      Enum.each(stopped, &set_terminate_request(&1, "stop"))
      insert_blocks(running_pipeline(), 3)

      assert {:ok, [{_, _}]} = WaitingStateScheduling.get_ready_block(unquote(order))

      in_scheduling =
        from(b in PplBlocks, where: b.in_scheduling == true, select: count(b.id))
        |> Repo.one()

      assert in_scheduling == 1
    end
  end

  # With index scans the rows come back in updated_at order even without
  # ORDER BY. Force sequential scans, where they come back in physical order,
  # which set_updated_at leaves different from updated_at order.
  test "claims oldest first without help from index order" do
    ppl_id = running_pipeline()
    [r0, r1, r2, t0, t1] = insert_blocks(ppl_id, 5)

    set_updated_at(r0, ~N[2026-01-01 10:00:00.000000])
    set_updated_at(r1, ~N[2026-01-01 08:00:00.000000])
    set_updated_at(r2, ~N[2026-01-01 09:00:00.000000])
    set_updated_at(t0, ~N[2026-01-01 07:00:00.000000])
    set_updated_at(t1, ~N[2026-01-01 06:00:00.000000])
    set_terminate_request(t0, "stop")
    set_terminate_request(t1, "stop")

    claimed =
      Repo.transaction(fn ->
        ~w(enable_indexscan enable_bitmapscan enable_indexonlyscan)
        |> Enum.each(&Repo.query!("SET LOCAL #{&1} = off"))

        for order <- [:terminate_first, :terminate_first, :ready_first, :ready_first, :ready_first] do
          {:ok, [{_, blk}]} = WaitingStateScheduling.do_get_ready_block(order)
          blk.id
        end
      end)

    assert claimed == {:ok, [t1.id, t0.id, r1.id, r2.id, r0.id]}
  end

  test "the waiting STM claims by its position in the batch" do
    alias Ppl.PplBlocks.STMHandler.WaitingState

    stopping_ppl = running_pipeline()
    [stopped] = insert_blocks(stopping_ppl, 1)
    ready_ppl = running_pipeline()
    [ready] = insert_blocks(ready_ppl, 1)

    "update pipelines set state = 'stopping' where ppl_id = $1;"
    |> Repo.query!([Ecto.UUID.dump!(stopping_ppl)])

    set_updated_at(stopped, ~N[2026-01-01 09:00:00.000000])
    set_updated_at(ready, ~N[2026-01-01 08:00:00.000000])
    set_terminate_request(stopped, "stop")

    assert {:ok, {_, %{id: first}}} = WaitingState.enter_scheduling(%{batch_index: 1})
    assert first == ready.id

    reset_in_scheduling()
    assert {:ok, {_, %{id: first}}} = WaitingState.enter_scheduling(%{batch_index: 0})
    assert first == stopped.id

    reset_in_scheduling()
    assert {:ok, {_, %{id: first}}} = WaitingState.enter_scheduling(%{})
    assert first == stopped.id
  end

  ################### Helpers ###################

  defp claim_all(acc) do
    case WaitingStateScheduling.get_ready_block() do
      {:ok, []} -> acc
      {:ok, [{_, blk}]} -> claim_all([blk.id | acc])
    end
  end

  defp claimed_id do
    assert {:ok, [{_old, blk}]} = WaitingStateScheduling.get_ready_block()
    assert blk.in_scheduling == true
    blk.id
  end

  defp running_pipeline do
    {:ok, %{ppl_id: ppl_id}} =
      Test.Helpers.schedule_request_factory(:local)
      |> Map.put("repo_name", "2_basic")
      |> Ppl.Actions.schedule()

    "update pipelines set state = 'running';" |> Repo.query!()
    ppl_id
  end

  defp insert_blocks(ppl_id, count) do
    for index <- 0..(count - 1) do
      {:ok, blk} =
        %PplBlocks{}
        |> PplBlocks.changeset(%{
          ppl_id: ppl_id,
          block_index: index,
          name: "blk #{index}",
          state: "waiting",
          in_scheduling: false
        })
        |> Repo.insert()

      blk
    end
  end

  defp set_updated_at(blk, updated_at) do
    from(b in PplBlocks, where: b.id == ^blk.id)
    |> Repo.update_all(set: [updated_at: updated_at])
  end

  defp lock_rows_nodes(node, in_init_plan) do
    in_init_plan = in_init_plan or String.starts_with?(node["Subplan Name"] || "", "InitPlan")
    own = if node["Node Type"] == "LockRows", do: [in_init_plan], else: []

    own ++ Enum.flat_map(node["Plans"] || [], &lock_rows_nodes(&1, in_init_plan))
  end

  defp reset_in_scheduling do
    PplBlocks |> Repo.update_all(set: [in_scheduling: false])
  end

  defp set_terminate_request(blk, request) do
    from(b in PplBlocks, where: b.id == ^blk.id)
    |> Repo.update_all(set: [terminate_request: request, terminate_request_desc: "API call"])
  end
end
