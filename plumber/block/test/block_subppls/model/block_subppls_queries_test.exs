defmodule Block.BlockSubppls.Model.BlockSubpplsQueries.Test do
  use ExUnit.Case
  doctest Block.BlockSubppls.Model.BlockSubpplsQueries

  alias Ecto.Multi
  alias Block.BlockSubppls.Model.BlockSubpplsQueries
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.BlockSubppls.Model.BlockSubppls
  alias Block.EctoRepo, as: Repo

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    args = %{"service" => "local", "repo_name" => "2_basic"}
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}
    includes = ["subpipeline_1.yml"]
    definition = %{"build" => build, "includes" => includes}
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: args,
                version: "v3.0", definition: definition, hook_id: UUID.uuid4()}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    id = blk_req.id
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: build})

    subppl_index = 0
    file_path = Enum.at(includes, subppl_index)

    {:ok, %{block_id: id, blk_req: blk_req, block_subppl_index: subppl_index, subppl_file_path: file_path}}
  end

  test "insert new block subppl", ctx do
    {:ok, blk_subppl} = insert_block_subppl(ctx.block_id, ctx.block_subppl_index, ctx.subppl_file_path)
    assert blk_subppl.state == "pending"
    assert blk_subppl.in_scheduling == false
    assert blk_subppl.subppl_file_path == ctx.subppl_file_path
    assert blk_subppl.block_subppl_index == ctx.block_subppl_index
    assert blk_subppl.recovery_count == 0
    clean_up(blk_subppl)
  end

  def insert_block_subppl(block_id, subppl_index, file_path) do
    event = %{block_id: block_id}
      |> Map.put(:block_subppl_index, subppl_index)
      |> Map.put(:subppl_file_path, file_path)
      |> Map.put(:state, "pending")
      |> Map.put(:in_scheduling, "false")

    %BlockSubppls{} |> BlockSubppls.changeset(event) |> Repo.insert
  end

  test "get subppl in pending and move it to scheduling", ctx do
    to_scheduling_from("pending", ctx)
  end

  test "get subppl in running and move it to scheduling", ctx do
    to_scheduling_from("running", ctx)
  end

  test "get subppl in stopping and move it to scheduling", ctx do
    to_scheduling_from("stopping", ctx)
  end

  test "move subppl from pending-scheduling to running", ctx do
    from_x_scheduling_to("pending", "running", ctx)
  end

  test "move subppl from pending-scheduling to done", ctx do
    from_x_scheduling_to("pending", "done", ctx)
  end

  test "move subppl from running-scheduling to stopping", ctx do
    from_x_scheduling_to("running", "stopping", ctx)
  end

  test "move subppl from running-scheduling to done", ctx do
    from_x_scheduling_to("running", "done", ctx)
  end

  test "move subppl from stopping-scheduling to done", ctx do
    from_x_scheduling_to("stopping", "done", ctx)
  end

  test "recover subppls stuck in scheduling", ctx do
    stuck_blk_subppl = create_event(ctx, "pending", true)
    id = stuck_blk_subppl.id
    recover_stuck_in_scheduling(stuck_blk_subppl)

    change_state_and_test(id, "running")
    change_state_and_test(id, "stopping")
    change_state_and_test(id, "done")
  end

  defp change_state_and_test(id, state) do
    BlockSubppls
    |> Repo.get(id)
    |> BlockSubppls.changeset(%{in_scheduling: :true, state: state})
    |> Repo.update()
    |> elem(1)
    |> recover_stuck_in_scheduling()
  end

  defp beholder_params() do
    %{repo: Block.EctoRepo, query: Block.BlockSubppls.Model.BlockSubppls, threshold_sec: -2, threshold_count: 5,
    terminal_state: "done", result_on_abort: "failed", result_reason_on_abort: "stuck",
    excluded_states: ["done"]}
  end

  # Recover all BlockSubppls stuck in scheduling and check if one of them has passed id value
  defp recover_stuck_in_scheduling(blk_subppl) do
    {_, recovered} = beholder_params() |> Looper.Beholder.Query.recover_stuck()

    recovered
    |> Enum.find(fn recovered_blk_subppl -> recovered_blk_subppl.id == blk_subppl.id end)
    |> recover_stuck_in_scheduling_(blk_subppl.state)
  end

  # BlockSubppl in "done" is not recovered
  defp recover_stuck_in_scheduling_(blk_subppl, "done"), do: assert blk_subppl == nil
  # BlockSubppls in other states are recovered - moved out of scheduling
  defp recover_stuck_in_scheduling_(blk_subppl, _state) do
    assert blk_subppl.in_scheduling == false
  end

  test "updated_at change on update_all() call", ctx do
    func = fn(ctx) -> insert_block_subppl(ctx.block_id, ctx.block_subppl_index, ctx.subppl_file_path) end
    blk_subppl = assert_blk_subppl_updated_at_set_properly(func, ctx)

    func = fn(_) -> to_scheduling("pending") end
    blk_subppl_returned = assert_blk_subppl_updated_at_set_properly(func, blk_subppl)
    assert blk_subppl.id == blk_subppl_returned.id

    func = fn(blk_subppl) -> to_state(blk_subppl, "done") end
    blk_subppl_returned = assert_blk_subppl_updated_at_set_properly(func, blk_subppl_returned)
    assert blk_subppl.id == blk_subppl_returned.id
  end

  defp assert_blk_subppl_updated_at_set_properly(func, args) do
    before_func = DateTime.utc_now |> DateTime.to_naive
    {:ok, blk_subppl} = func.(args)
    after_func = DateTime.utc_now |> DateTime.to_naive
    assert NaiveDateTime.compare(before_func, blk_subppl.updated_at) == :lt
    assert NaiveDateTime.compare(after_func, blk_subppl.updated_at) == :gt
    blk_subppl
  end

  def query_params() do
    %{initial_query: Block.BlockSubppls.Model.BlockSubppls, cooling_time_sec: -2,
      repo: Block.EctoRepo, schema: Block.BlockSubppls.Model.BlockSubppls, returning: [:id, :block_id],
      allowed_states: ~w(pending running stopping done)}
  end

  def to_scheduling(state) do
    params = query_params() |> Map.put(:observed_state, state)
    {:ok, %{enter_transition: blk_subppl}} = Looper.STM.Impl.enter_scheduling(params)
    {:ok, blk_subppl}
  end

  def to_state(subppl, state) do
    args = query_params()
    Looper.STM.Impl.exit_scheduling(subppl, fn _, _ -> {:ok, %{state: state}} end, args)
    BlockSubpplsQueries.get_by_block_data(subppl.block_id, subppl.block_subppl_index)
  end

  defp to_scheduling_from(state, ctx) do
    _blk_subppl = create_event(ctx, state, false)
    {:ok, blk_subppl} = to_scheduling(state)
    assert blk_subppl.state == state
    assert blk_subppl.in_scheduling == true
    clean_up(blk_subppl)
  end

  defp from_x_scheduling_to(from_state, to_state, ctx) do
    blk_subppl = create_event(ctx, from_state, true)
    {:ok, blk_subppl} = to_state(blk_subppl, to_state)
    assert blk_subppl.state == to_state
    assert blk_subppl.in_scheduling == false
    clean_up(blk_subppl)
  end

  defp create_event(ctx, state, in_scheduling) do
    params = event_params(ctx, state, in_scheduling)
    {:ok, blk_subppl} = %BlockSubppls{} |> BlockSubppls.changeset(params) |> Repo.insert
    assert blk_subppl.state == state
    assert blk_subppl.in_scheduling == in_scheduling
    blk_subppl
  end

  defp event_params(ctx, state, in_scheduling) do
    Map.merge(ctx, %{state: state, in_scheduling: in_scheduling})
  end

  defp clean_up(blk_subppl) do
    blk_subppl |> BlockSubppls.changeset(%{state: "done"}) |> Repo.update
  end

  test "valid call to add insert changeset to multi", ctx do
    test_multi_insert_with_params("test", 0, ctx.blk_req, true)
  end

  test "invalid call to add insert changeset to multi - index not number", ctx do
    test_multi_insert_with_params("test", "not_integer", ctx.blk_req, false)
  end

  test "invalid call to add insert changeset to multi - file_path not string", ctx do
    test_multi_insert_with_params(:invalid_value, 0, ctx.blk_req, false)
  end

  defp test_multi_insert_with_params(file_name, index, blk_req, valid?) do
    multi = BlockSubpplsQueries.multi_insert(Multi.new, blk_req, {file_name, index})

    name = String.to_atom("block_subppl_#{index}")

    assert MapSet.member?(Map.get(multi, :names), name)
    operations = Map.get(multi, :operations)
    assert Keyword.has_key?(operations, name)

    changeset_tuple = Keyword.get(operations, name)
    assert elem(changeset_tuple, 0) == :changeset

    changeset = elem(changeset_tuple, 1)
    assert changeset.action == :insert
    assert changeset.valid? == valid?
    assert changeset.data ==  %BlockSubppls{}

    assert Map.get(changeset.changes, :block_id) == blk_req.id
    assert Map.get(changeset.changes, :state) == "pending"
    assert Map.get(changeset.changes, :in_scheduling) == false

    assert_includes_element(changeset, :block_subppl_index, index, is_integer(index))
    assert_includes_element(changeset, :subppl_file_path, file_name, is_binary(file_name))
  end

  defp assert_includes_element(changeset, element_name, element_value, true) do
    assert Map.get(changeset.changes, element_name) == element_value
  end

  defp assert_includes_element(changeset, element_name, _element_value, _) do
    assert Keyword.has_key?(changeset.errors, element_name)
  end

  test "get subppl by block_id and index in block's include list", ctx do
    assert {:ok, blk_subppl} = insert_block_subppl(ctx.block_id, ctx.block_subppl_index, ctx.subppl_file_path)

    assert {:ok, result} = BlockSubpplsQueries.get_by_block_data(ctx.block_id, ctx.block_subppl_index)
    assert blk_subppl == result
  end

  test "invalid - get subppl by invalid block_id and valid index in block's include list", ctx do
    assert {:ok, _blk_subppl} = insert_block_subppl(ctx.block_id, ctx.block_subppl_index, ctx.subppl_file_path)

    wrong_id = UUID.uuid4()
    assert {:error, message} = BlockSubpplsQueries.get_by_block_data(wrong_id, ctx.block_subppl_index)
    assert message == "no subppl for block: #{wrong_id} with index: #{ctx.block_subppl_index} found"
  end

  test "invalid - get subppl by valid block_id and invalid index in block's include list", ctx do
    assert {:ok, _blk_subppl} = insert_block_subppl(ctx.block_id, ctx.block_subppl_index, ctx.subppl_file_path)

    assert {:error, message} = BlockSubpplsQueries.get_by_block_data(ctx.block_id, -1)
    assert message == "no subppl for block: #{ctx.block_id} with index: -1 found"
  end

  test "get all subppls from block with given block_id", ctx do
    assert {:ok, blk_subppl_1} = insert_block_subppl(ctx.block_id, ctx.block_subppl_index, ctx.subppl_file_path)
    assert {:ok, blk_subppl_2} = insert_block_subppl(ctx.block_id, 1, ctx.subppl_file_path)

    assert {:ok, result} = BlockSubpplsQueries.get_all_by_id(ctx.block_id)
    assert [blk_subppl_1, blk_subppl_2] == result
  end

  test "invalid - get all subppls from block with wrong block_id", ctx do
    assert {:ok, _blk_subppl_1} = insert_block_subppl(ctx.block_id, ctx.block_subppl_index, ctx.subppl_file_path)
    assert {:ok, _blk_subppl_2} = insert_block_subppl(ctx.block_id, 1, ctx.subppl_file_path)

    wrong_id = UUID.uuid4()
    assert {:error, message} = BlockSubpplsQueries.get_all_by_id(wrong_id)
    assert message == "no subppl's for block with id: #{wrong_id} found"
  end

end
