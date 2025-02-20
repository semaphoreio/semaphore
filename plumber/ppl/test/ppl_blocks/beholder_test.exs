defmodule Ppl.PplBlocks.Beholder.Test do
  use ExUnit.Case

  alias Ppl.PplBlocks.Beholder
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.PplBlocks.Model.PplBlocks
  alias Ppl.EctoRepo, as: Repo

  setup do
    Test.Helpers.truncate_db()

    request = Test.Helpers.schedule_request_factory(:local)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}

    definition_v3 = %{"version" => "v3.0", "semaphore_image" => "some_image", "blocks" => [%{"build" => build}]}

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    id = ppl_req.id
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition_v3)

    {:ok, %{ppl_id: id, ppl_req: ppl_req}}
  end

  test "pipeline's block is terminated when recovery counter reaches threshold", ctx do
    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0)
    assert ppl_blk.state == "waiting"
    assert ppl_blk.recovery_count == 0
    assert {:ok, ppl_blk} = ppl_blk
      |> PplBlocks.changeset(%{recovery_count: 5, in_scheduling: true})
      |> Repo.update
    assert ppl_blk.recovery_count == 5
    assert ppl_blk.in_scheduling == true

    assert {:ok, pid} = Beholder.start_link()
    args = [ppl_blk.state, ppl_blk, pid]
    Test.Helpers.assert_finished_for_less_than(__MODULE__, :transitioned_to_done, args, 5_000)
  end

  def transitioned_to_done(state, ppl_blk, pid) when state != "done" do
    :timer.sleep(100)
    ppl_blk = Repo.get(PplBlocks, ppl_blk.id)
    transitioned_to_done(ppl_blk.state, ppl_blk, pid)
  end
  def transitioned_to_done("done", ppl_blk, pid) do
    assert ppl_blk.state == "done"
    assert ppl_blk.in_scheduling == true
    assert ppl_blk.recovery_count == 5
    Process.exit(pid, :normal)
  end

  test "recovery counter is incremented when ppl block event is recovered from stuck", ctx do
    assert {:ok, looper_pid} = Beholder.start_link()

    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0)
    assert ppl_blk.state == "waiting"
    assert {:ok, ppl_blk} = to_scheduling("waiting")
    assert ppl_blk.in_scheduling == true

    Test.Helpers.assert_finished_for_less_than(
      __MODULE__, :recovery_count_is_incremented_assert,
      [ppl_blk.recovery_count, ppl_blk, looper_pid],
      5_000)
  end

  def query_params() do
    %{initial_query: Ppl.PplBlocks.Model.PplBlocks, cooling_time_sec: -2,
      repo: Ppl.EctoRepo, schema: Ppl.PplBlocks.Model.PplBlocks, returning: [:id, :ppl_id],
      allowed_states: ~w(waiting running stopping done)}
  end

  def to_scheduling(state) do
    params = query_params() |> Map.put(:observed_state, state)
    {:ok, %{enter_transition: ppl_blk}} = Looper.STM.Impl.enter_scheduling(params)
    {:ok, ppl_blk}
  end

  defp insert_ppl_blk(ppl_id, block_index) do
    params = %{ppl_id: ppl_id, block_index: block_index}
      |> Map.put(:state, "waiting")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:recovery_count, 0)
      |> Map.put(:name, "blk #{inspect(block_index)}")

    %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert
  end

  def recovery_count_is_incremented_assert(recovery_count, ppl_blk, looper_pid)
  when recovery_count == 0 do
    :timer.sleep(100)
    ppl_blk = Repo.get(PplBlocks, ppl_blk.id)

    recovery_count_is_incremented_assert(ppl_blk.recovery_count, ppl_blk, looper_pid)
  end
  def recovery_count_is_incremented_assert(_recovery_count, ppl_blk, looper_pid) do
    assert ppl_blk.recovery_count > 0
    Process.exit(looper_pid, :normal)
  end

  test "child_spec accepts 1 arg and returns a map" do
    assert Beholder.child_spec([]) |> is_map()
  end
end
