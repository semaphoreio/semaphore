defmodule Ppl.PplBlocks.Model.PplBlocksQueries.Test do
  use ExUnit.Case
  doctest Ppl.PplBlocks.Model.PplBlocksQueries, import: true

  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries}
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.EctoRepo, as: Repo

  setup do
    Test.Helpers.truncate_db()

    request = Test.Helpers.schedule_request_factory(:local)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}

    definition_v1 = %{"version" => "v1.0", "semaphore_image" => "some_image",
      "blocks" => [%{"name" => "block 1", "build" => build}]}
    definition_v3 = %{"version" => "v3.0", "semaphore_image" => "some_image",
      "blocks" => [%{"name" => "block 1", "build" => build}]}

    {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    id = ppl_req.id
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition_v1)

    request = %{request | "request_token" => UUID.uuid4()}
    {:ok, ppl_req_v3} = PplRequestsQueries.insert_request(request)
    id_v3 = ppl_req_v3.id
    {:ok, ppl_req_v3} = PplRequestsQueries.insert_definition(ppl_req_v3, definition_v3)

    {:ok, %{ppl_id: id, ppl_req: ppl_req, ppl_v3_id: id_v3, ppl_req_v3: ppl_req_v3}}
  end

  test "insert new pipeline block event", ctx do
    insert_pipeline_block(ctx.ppl_id)
    insert_pipeline_block(ctx.ppl_v3_id)
  end

  defp insert_pipeline_block(ppl_id) do
    {:ok, ppl_blk} = insert_ppl_blk(ppl_id, 0)
    assert ppl_blk.state == "waiting"
    assert ppl_blk.in_scheduling == false
    assert ppl_blk.block_index == 0
    assert ppl_blk.recovery_count == 0
    clean_up(ppl_blk)
  end

  defp insert_ppl_blk(ppl_id, block_index) do
    params = %{ppl_id: ppl_id, block_index: block_index,
      name: "blk #{inspect block_index}"}
      |> Map.put(:state, "waiting")
      |> Map.put(:in_scheduling, "false")

    %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert
  end

  test "should_do_fast_failing?() returns {:ok, false} when no blocks have failed or were terminated", ctx do
    assert {:ok, ppl_blk_1} = insert_ppl_blk(ctx.ppl_v3_id, 0)
    assert ppl_blk_1.state == "waiting"
    assert {:ok, ppl_blk_2} = insert_ppl_blk(ctx.ppl_v3_id, 1)
    assert ppl_blk_2.state == "waiting"

    assert {:ok, false} == PplBlocksQueries.should_do_fast_failing?(ppl_blk_2)

    assert {:ok, ppl} = ctx.ppl_req_v3 |> Map.from_struct() |> PplsQueries.insert()
    assert {:ok, _ppl} = ppl |> Ppls.changeset(%{fast_failing: "stop"}) |> Repo.update()

    assert {:ok, false} == PplBlocksQueries.should_do_fast_failing?(ppl_blk_2)
  end

  test "should_do_fast_failing?() returns {:ok, false} when some blocks fail and fast_failing isn't set", ctx do
    assert {:ok, ppl_blk_1} = insert_ppl_blk(ctx.ppl_v3_id, 0)
    assert {:ok, ppl_blk_1} = to_state(ppl_blk_1, "done", %{result: "failed"})
    assert ppl_blk_1.state == "done"
    assert ppl_blk_1.result == "failed"
    assert {:ok, ppl_blk_2} = insert_ppl_blk(ctx.ppl_v3_id, 1)
    assert ppl_blk_2.state == "waiting"

    assert {:ok, false} == PplBlocksQueries.should_do_fast_failing?(ppl_blk_2)
  end

  test "should_do_fast_failing?() returns {:ok, fast_failing} when some blocks fail and fast_failing is set", ctx do
    assert {:ok, ppl_blk_1} = insert_ppl_blk(ctx.ppl_v3_id, 0)
    assert {:ok, ppl_blk_1} = to_state(ppl_blk_1, "done", %{result: "failed"})
    assert ppl_blk_1.state == "done"
    assert ppl_blk_1.result == "failed"
    assert {:ok, ppl_blk_2} = insert_ppl_blk(ctx.ppl_v3_id, 1)
    assert ppl_blk_2.state == "waiting"

    assert {:ok, ppl} = ctx.ppl_req_v3 |> Map.from_struct() |> PplsQueries.insert()
    assert {:ok, _ppl} = ppl |> Ppls.changeset(%{fast_failing: "stop"}) |> Repo.update()

    assert {:ok, "stop"} == PplBlocksQueries.should_do_fast_failing?(ppl_blk_2)
  end

  test "get pipeline block in waiting and move it to scheduling", ctx do
    v1(:to_scheduling_from, ["waiting"], ctx)
    v3(:to_scheduling_from, ["waiting"], ctx)
  end

  test "get pipeline block in running and move it to scheduling", ctx do
    v1(:to_scheduling_from, ["running"], ctx)
    v3(:to_scheduling_from, ["running"], ctx)
  end

  test "get pipeline block in stopping and move it to scheduling", ctx do
    v1(:to_scheduling_from, ["stopping"], ctx)
    v3(:to_scheduling_from, ["stopping"], ctx)
  end

  test "move pipeline block from waiting-scheduling to running", ctx do
    v1(:from_x_scheduling_to, ["waiting", "running"], ctx)
    v3(:from_x_scheduling_to, ["waiting", "running"], ctx)
  end

  test "move pipeline block from waiting-scheduling to done", ctx do
    v1(:from_x_scheduling_to, ["waiting", "done"], ctx)
    v3(:from_x_scheduling_to, ["waiting", "done"], ctx)
  end

  test "move pipeline block from running-scheduling to stopping", ctx do
    v1(:from_x_scheduling_to, ["running", "stopping"], ctx)
    v3(:from_x_scheduling_to, ["running", "stopping"], ctx)
  end

  test "move pipeline block from running-scheduling to done", ctx do
    v1(:from_x_scheduling_to, ["running", "done"], ctx)
    v3(:from_x_scheduling_to, ["running", "done"], ctx)
  end

  test "move pipeline block from stopping-scheduling to done", ctx do
    v1(:from_x_scheduling_to, ["stopping", "done"], ctx)
    v3(:from_x_scheduling_to, ["stopping", "done"], ctx)
  end

  test "recover pipeline blocks stuck in scheduling", ctx do
    stuck_ppl_blk = create_block(ctx, "waiting", true)
    id = stuck_ppl_blk.id
    recover_stuck_in_scheduling(stuck_ppl_blk)

    change_state_and_test(id, "running")
    change_state_and_test(id, "stopping")
    change_state_and_test(id, "done")
  end

  test "get ppl's block by ppl_id and index in ppl request's blocks list", ctx do
    {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0)

    assert {:ok, result} = PplBlocksQueries.get_by_id_and_index(ctx.ppl_id, 0)
    assert ppl_blk == result
    clean_up(ppl_blk)
  end

  test "invalid - get block by invalid ppl_id and valid index in ppl request's blocks list", ctx do
    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0)

    wrong_id = UUID.uuid4()
    assert {:error, {:not_found, message}} = PplBlocksQueries.get_by_id_and_index(wrong_id, 0)
    assert message == "block with index 0 for ppl: #{wrong_id} not found"
    clean_up(ppl_blk)
  end

  test "invalid - get block by valid ppl_id and invalid index in ppl request's blocks list", ctx do
    assert {:ok, ppl_blk} = insert_ppl_blk(ctx.ppl_id, 0)

    assert {:error, {:not_found, message}} = PplBlocksQueries.get_by_id_and_index(ctx.ppl_id, -1)
    assert message == "block with index -1 for ppl: #{ctx.ppl_id} not found"
    clean_up(ppl_blk)
  end

  test "get all blocks from ppl with given ppl_id", ctx do
    assert {:ok, ppl_blk_1} = insert_ppl_blk(ctx.ppl_v3_id, 0)
    assert {:ok, ppl_blk_2} = insert_ppl_blk(ctx.ppl_v3_id, 1)

    assert {:ok, result} = PplBlocksQueries.get_all_by_id(ctx.ppl_v3_id)
    assert [ppl_blk_1, ppl_blk_2] == result
    clean_up(ppl_blk_1)
    clean_up(ppl_blk_2)
  end

  test "invalid - get all blocks from ppl with wrong ppl_id", ctx do
    assert {:ok, ppl_blk_1} = insert_ppl_blk(ctx.ppl_v3_id, 0)
    assert {:ok, ppl_blk_2} = insert_ppl_blk(ctx.ppl_v3_id, 1)

    wrong_id = UUID.uuid4()
    assert {:error, message} = PplBlocksQueries.get_all_by_id(wrong_id)
    assert message == "no ppl blocks for ppl with id: #{wrong_id} found"
    clean_up(ppl_blk_1)
    clean_up(ppl_blk_2)
  end

  defp change_state_and_test(id, state) do
    PplBlocks
    |> Repo.get(id)
    |> PplBlocks.changeset(%{in_scheduling: :true, state: state})
    |> Repo.update
    |> elem(1)
    |> recover_stuck_in_scheduling()
  end

  defp beholder_params() do
    %{repo: Ppl.EctoRepo, query: Ppl.PplBlocks.Model.PplBlocks, threshold_sec: -2, threshold_count: 5,
    terminal_state: "done", result_on_abort: "failed", result_reason_on_abort: "stuck",
    excluded_states: ["done"]}
  end

  # Recover all PplBlocks stuck in scheduling and check if one of them has passed id value
  defp recover_stuck_in_scheduling(ppl_blk) do
    {_, recovered} = beholder_params() |> Looper.Beholder.Query.recover_stuck()

    Enum.find(recovered, fn recovered_ppl_blk -> recovered_ppl_blk.id == ppl_blk.id end)
    |> recover_stuck_in_scheduling_(ppl_blk.state)
  end

  # PplBlock in "done" is not recovered
  defp recover_stuck_in_scheduling_(ppl_blk, "done"), do: assert ppl_blk == nil
  # PplBlocks in other states are recovered - moved out of scheduling
  defp recover_stuck_in_scheduling_(ppl_blk, _state) do
    assert ppl_blk.in_scheduling == false
  end

  test "updated_at change on update_all() call", ctx do
    test_updated_at(ctx.ppl_req)
    test_updated_at(ctx.ppl_req_v3)
  end

  defp test_updated_at(ppl_req) do
    func = fn(ppl_req) -> insert_ppl_blk(ppl_req.id, 0) end
    ppl_blk = assert_ppl_blk_updated_at_set_properly(func, ppl_req)

    func = fn(_) -> to_scheduling("waiting") end
    ppl_blk_returned = assert_ppl_blk_updated_at_set_properly(func, ppl_blk)
    assert ppl_blk.id == ppl_blk_returned.id

    func = fn(ppl_blk) -> to_state(ppl_blk, "done") end
    ppl_blk_returned = assert_ppl_blk_updated_at_set_properly(func, ppl_blk_returned)
    assert ppl_blk.id == ppl_blk_returned.id
  end

  defp assert_ppl_blk_updated_at_set_properly(func, args) do
    before_func = DateTime.utc_now |> DateTime.to_naive
    {:ok, ppl_blk} = func.(args)
    after_func = DateTime.utc_now |> DateTime.to_naive
    assert NaiveDateTime.compare(before_func, ppl_blk.updated_at) == :lt
    assert NaiveDateTime.compare(after_func, ppl_blk.updated_at ) == :gt
    ppl_blk
  end

  defp v1(fun, args, ctx) do
    ctx =  Map.delete(ctx, :ppl_v3_id)
    ctx =  Map.delete(ctx, :ppl_v3)
    args = args ++ [ctx]
    apply(__MODULE__, fun, args)
  end

  defp v3(fun, args, ctx) do
    ctx =  Map.put(ctx, :ppl_id, Map.get(ctx, :ppl_v3_id))
    ctx =  Map.put(ctx, :ppl, Map.get(ctx, :ppl))
    ctx =  Map.delete(ctx, :ppl_v3_id)
    ctx =  Map.delete(ctx, :ppl_v3)
    args = args ++ [ctx]
    apply(__MODULE__, fun, args)
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

  def to_state(ppl_blk, state, additional_params \\ %{}) do
    params =  %{state: state} |> Map.merge(additional_params)
    args = query_params()
    Looper.STM.Impl.exit_scheduling(ppl_blk, fn _, _ -> {:ok, params} end, args)
    PplBlocksQueries.get_by_id_and_index(ppl_blk.ppl_id, ppl_blk.block_index)
  end

  def to_scheduling_from(state, ctx) do
    _ppl_blk = create_block(ctx, state, false)
    {:ok, ppl_blk} = to_scheduling(state)
    assert ppl_blk.state == state
    assert ppl_blk.in_scheduling == true
    clean_up(ppl_blk)
  end

  def from_x_scheduling_to(from_state, to_state, ctx) do
    ppl_blk = create_block(ctx, from_state, true)
    {:ok, ppl_blk} = to_state(ppl_blk, to_state)
    assert ppl_blk.state == to_state
    assert ppl_blk.in_scheduling == false
    clean_up(ppl_blk)
  end

  defp create_block(ctx, state, in_scheduling) do
    params = block_params(ctx, state, in_scheduling)
    {:ok, ppl_blk} = %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert
    assert ppl_blk.state == state
    assert ppl_blk.in_scheduling == in_scheduling
    ppl_blk
  end

  defp block_params(ctx, state, in_scheduling) do
    Map.merge(ctx, %{state: state, block_index: 0, in_scheduling: in_scheduling,
      name: "blk #{UUID.uuid1()}"})
  end

  defp clean_up(ppl_blk) do
    ppl_blk |> PplBlocks.changeset(%{state: "done"}) |> Repo.update
  end
end
