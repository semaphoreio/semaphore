defmodule Ppl.Ppls.Beholder.Test do
  use Ppl.IntegrationCase

  alias InternalApi.Plumber.Pipeline.Result
  alias Ppl.Actions
  alias Ppl.Ppls.Beholder
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.EctoRepo, as: Repo

  setup do
    Test.Helpers.truncate_db()

    :ok
  end

  test "pipeline is terminated when recovery counter reaches threshold" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)

    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert ppl.state == "initializing"
    assert {:ok, ppl} = ppl
      |> Ppls.changeset(%{recovery_count: 5, in_scheduling: true})
      |> Repo.update
    assert ppl.recovery_count == 5
    assert ppl.in_scheduling == true

    assert {:ok, pid} = Beholder.start_link()
    args = [ppl.state, ppl, pid]
    Test.Helpers.assert_finished_for_less_than(__MODULE__, :transitioned_to_done, args, 5_000)
  end

  def transitioned_to_done(state, ppl, pid) when state != "done" do
    :timer.sleep(100)
    ppl = Repo.get(Ppls, ppl.id)
    transitioned_to_done(ppl.state, ppl, pid)
  end
  def transitioned_to_done("done", ppl, pid) do
    assert ppl.state == "done"
    assert ppl.in_scheduling == true
    assert ppl.recovery_count == 5
    Process.exit(pid, :normal)
  end

  test "recovery counter is incremented when pipeline is recovered from stuck" do
    request = Test.Helpers.schedule_request_factory(:local)
    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)

    assert {:ok, looper_pid} = Beholder.start_link()

    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert ppl.state == "initializing"
    assert {:ok, ppl} = to_scheduling("initializing")
    assert ppl.in_scheduling == true

    Test.Helpers.assert_finished_for_less_than(
      __MODULE__, :recovery_count_is_incremented_assert,
      [ppl.recovery_count, ppl, looper_pid],
      5_000)
  end

  def query_params() do
    %{initial_query: Ppl.Ppls.Model.Ppls, cooling_time_sec: -2,
      repo: Ppl.EctoRepo, schema: Ppl.Ppls.Model.Ppls, returning: [:id, :ppl_id],
      allowed_states: ~w(initializing pending queuing running stopping done)}
  end

  def to_scheduling(state) do
    params = query_params() |> Map.put(:observed_state, state)
    {:ok, %{enter_transition: pple}} = Looper.STM.Impl.enter_scheduling(params)
    {:ok, pple}
  end

  def recovery_count_is_incremented_assert(recovery_count, ppl, looper_pid)
  when recovery_count == 0 do
    :timer.sleep(100)
    ppl = Repo.get(Ppls, ppl.id)

    recovery_count_is_incremented_assert(ppl.recovery_count, ppl, looper_pid)
  end
  def recovery_count_is_incremented_assert(_recovery_count, ppl, looper_pid) do
    assert ppl.recovery_count > 0
    Process.exit(looper_pid, :normal)
  end

  test "child_spec accepts 1 arg and returns a map" do
    assert Beholder.child_spec([]) |> is_map()
  end

  @tag :integration
  test "PplBlocks are terminated when ppl is stuck-aborted" do
    import Ecto.Query

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "13_free_topology"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    {:ok, _ppl} = Ppl.Ppls.Model.PplsQueries.get_by_id(ppl_id)

    Ppls
    |> where(ppl_id: ^ppl_id)
    |> update(set: [recovery_count: 100, in_scheduling: true])
    |> Repo.update_all([])

    {:ok, _ppl} = Ppl.Ppls.Model.PplsQueries.get_by_id(ppl_id)

    assert {:ok, pid} = Beholder.start_link()
    loopers = Test.Helpers.start_all_loopers()

    {:ok, ppl} =  Test.Helpers.wait_for_ppl_state(ppl_id, "done", 10_000)

    {:ok, _} =
      Test.Helpers.assert_finished_for_less_than(
        __MODULE__, :do_wait_block_status, [ppl_id,
        %{"A" => [state: "done", result: "canceled"], "B" => [state: "done", result: "canceled"],
        "C" => [state: "done", result: "canceled"], "D" => [state: "done", result: "canceled"],
        "E" =>[state: "done", result: "canceled"]}], 10_000)

    assert :ok = Beholder.stop(pid)
    Test.Helpers.stop_all_loopers(loopers)

    assert ppl.result == "failed"
  end

  def do_wait_block_status(ppl_id, desired_status) do
    :timer.sleep 100
    {:ok, blocks} = PplBlocksQueries.get_all_by_id(ppl_id)
    if reached_desired_status?(blocks, desired_status) do
      blocks
    else
      do_wait_block_status(ppl_id, desired_status)
    end
  end

  defp reached_desired_status?(blocks, desired_status) do
    Enum.map(desired_status, fn {k, v} ->
      Enum.find_value(blocks,
      fn block ->
        block.name == k && block.state == Keyword.get(v, :state) && block.result == Keyword.get(v, :result)
      end)
    end)
    |> Enum.all?(fn(x) -> x != nil end)
  end

end
