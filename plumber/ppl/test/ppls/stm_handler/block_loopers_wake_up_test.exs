defmodule Ppl.Ppls.STMHandler.BlockLoopersWakeUpTest do
  use Ppl.IntegrationCase

  import Ecto.Query

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries}
  alias Ppl.PplBlocks.STMHandler.InitializingState, as: BlkInitializing
  alias Ppl.PplBlocks.STMHandler.RunningState, as: BlkRunning
  alias Ppl.PplBlocks.WaitingDrain
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.Ppls.STMHandler.Common

  setup do
    Test.Helpers.truncate_db()

    # Loopers are not started in the test env. Stand-ins registered under their
    # names forward every cast to the test process, so the test sees exactly
    # which wake-ups were sent.
    test_pid = self()

    for name <- [BlkInitializing, BlkRunning, WaitingDrain] do
      pid = spawn_link(fn -> forward(name, test_pid) end)
      Process.register(pid, name)
    end

    :ok
  end

  describe "trigger_ppl_block_loopers/1 (pipeline transitions)" do
    test "wakes the matching looper only for initializing and running blocks" do
      ppl_id = insert_ppl(6)
      set_states(ppl_id, ~w(initializing running waiting done stopping running))

      Common.trigger_ppl_block_loopers(exit_data(ppl_id))

      assert wake_ups() == [
               {BlkInitializing, 0},
               {BlkRunning, 1},
               {BlkRunning, 5},
               {WaitingDrain, ppl_id}
             ]
    end

    test "still drains waiting blocks when no block is initializing or running" do
      ppl_id = insert_ppl(3)
      set_states(ppl_id, ~w(waiting done waiting))

      Common.trigger_ppl_block_loopers(exit_data(ppl_id))

      assert wake_ups() == [{WaitingDrain, ppl_id}]
    end

    test "does nothing without a pipeline id" do
      Common.trigger_ppl_block_loopers(%{})
      assert wake_ups() == []
    end
  end

  describe "trigger_ppl_block_loopers_on_block_done/1" do
    test "passed block wakes no sibling" do
      ppl_id = insert_ppl(4)
      set_states(ppl_id, ~w(done initializing running running))

      Common.trigger_ppl_block_loopers_on_block_done(exit_data(ppl_id, "passed"))

      assert wake_ups() == []
    end

    for result <- ~w(failed stopped canceled) do
      test "#{result} block wakes initializing and running siblings for fast failing" do
        ppl_id = insert_ppl(4)
        set_states(ppl_id, ~w(done initializing running waiting))

        Common.trigger_ppl_block_loopers_on_block_done(exit_data(ppl_id, unquote(result)))

        assert wake_ups() == [{BlkInitializing, 1}, {BlkRunning, 2}]
      end
    end

    test "woken predicates select exactly the targeted blocks" do
      ppl_id = insert_ppl(3)
      set_states(ppl_id, ~w(done running initializing))

      Common.trigger_ppl_block_loopers_on_block_done(exit_data(ppl_id, "failed"))

      picked =
        collect([])
        |> Enum.map(fn {_name, {:wake_up, predicate}} ->
          PplBlocks |> predicate.() |> Repo.one!() |> Map.take([:ppl_id, :block_index])
        end)

      assert Enum.sort_by(picked, & &1.block_index) == [
               %{ppl_id: ppl_id, block_index: 1},
               %{ppl_id: ppl_id, block_index: 2}
             ]
    end

    test "fast failing reaches a running sibling of a failed block" do
      ppl_id = insert_ppl(2)
      set_states(ppl_id, ~w(done running))

      from(pb in PplBlocks, where: pb.ppl_id == ^ppl_id and pb.block_index == 0)
      |> Repo.update_all(set: [result: "failed"])

      from(p in Ppl.Ppls.Model.Ppls, where: p.ppl_id == ^ppl_id)
      |> Repo.update_all(set: [fast_failing: "stop"])

      Common.trigger_ppl_block_loopers_on_block_done(exit_data(ppl_id, "failed"))
      assert wake_ups() == [{BlkRunning, 1}]

      {:ok, sibling} = PplBlocksQueries.get_by_id_and_index(ppl_id, 1)
      assert {:ok, "stop"} = PplBlocksQueries.should_do_fast_failing?(sibling)
    end
  end

  describe "PplBlocksQueries.indexes_in_states/2" do
    test "returns only blocks of the given pipeline in the given states" do
      ppl_id = insert_ppl(3)
      other_id = insert_ppl(2)
      set_states(ppl_id, ~w(running waiting initializing))
      set_states(other_id, ~w(running running))

      assert PplBlocksQueries.indexes_in_states(ppl_id, ["initializing", "running"]) ==
               [{0, "running"}, {2, "initializing"}]

      assert PplBlocksQueries.indexes_in_states(ppl_id, ["done"]) == []
    end
  end

  defp forward(name, test_pid) do
    receive do
      {:"$gen_cast", msg} ->
        send(test_pid, {:wake_up, name, msg})
        forward(name, test_pid)
    end
  end

  defp collect(acc) do
    receive do
      {:wake_up, name, msg} -> collect([{name, msg} | acc])
    after
      200 -> Enum.reverse(acc)
    end
  end

  defp wake_ups do
    collect([])
    |> Enum.map(fn
      {WaitingDrain, {:trigger, ppl_id}} ->
        {WaitingDrain, ppl_id}

      {name, {:wake_up, predicate}} ->
        %{block_index: index} = PplBlocks |> predicate.() |> Repo.one!()
        {name, index}
    end)
    |> Enum.sort_by(fn {name, key} -> {name == WaitingDrain, inspect(name), key} end)
  end

  defp exit_data(ppl_id, result \\ nil) do
    %{exit_transition: %{ppl_id: ppl_id}, user_exit_function: %{state: "done", result: result}}
  end

  defp set_states(ppl_id, states) do
    states
    |> Enum.with_index()
    |> Enum.each(fn {state, index} ->
      from(pb in PplBlocks, where: pb.ppl_id == ^ppl_id and pb.block_index == ^index)
      |> Repo.update_all(set: [state: state])
    end)
  end

  defp insert_ppl(block_count) do
    blocks =
      for i <- 1..block_count do
        %{"name" => "block #{i}", "build" => %{"jobs" => [%{"name" => "job", "commands" => ["echo"]}]}}
      end

    definition = %{"version" => "v1.0", "blocks" => blocks}

    request_args =
      %{"request_token" => UUID.uuid4()}
      |> Test.Helpers.schedule_request_factory(:local)

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request_args)
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)
    {:ok, ppl} = PplsQueries.insert(ppl_req)

    {:ok, _} =
      Ecto.Multi.new()
      |> PplBlocksQueries.multi_insert(ppl_req)
      |> Repo.transaction()

    ppl.ppl_id
  end
end
