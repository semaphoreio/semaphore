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

  defp set_terminate_request(blk, request) do
    from(b in PplBlocks, where: b.id == ^blk.id)
    |> Repo.update_all(set: [terminate_request: request, terminate_request_desc: "API call"])
  end
end
