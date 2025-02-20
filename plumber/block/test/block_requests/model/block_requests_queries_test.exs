defmodule Block.BlockRequests.Model.BlockRequestsQueries.Test do
  use ExUnit.Case
  doctest Block.BlockRequests.Model.BlockRequestsQueries

  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Blocks.Model.BlocksQueries
  alias Block.Tasks.Model.TasksQueries
  alias Block.BlockSubppls.Model.BlockSubpplsQueries
  alias Block.EctoRepo, as: Repo
  alias Ecto.Multi

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    request_args = %{"service" => "local", "repo_name" => "2_basic"}
    job_1 = %{"name" => "job1", "cmds" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "cmds" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}
    definition_v1 = %{"build" => build}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition_v3 = Map.put(definition_v1, "includes", includes)
    {:ok, %{request_args: request_args, definition_v1: definition_v1, definition_v3: definition_v3}}
  end

  test "blk_req insert is idempotent operation", ctx do
    {:ok, args} = Map.fetch(ctx, :request_args)
    ppl_id = UUID.uuid4()
    hook_id = UUID.uuid4()
    definition = Map.get(ctx, :definition_v3)

    request = %{ppl_id: ppl_id}
    |> Map.put(:pple_block_index, 0)
    |> Map.put(:request_args, args)
    |> Map.put(:version, "v3.0")
    |> Map.put(:definition, definition)
    |> Map.put(:hook_id, hook_id)

    assert {:ok, blk_req_1} = BlockRequestsQueries.insert_request(request)
    assert {:ok, blk_req_2} = BlockRequestsQueries.insert_request(request)
    assert blk_req_1.inserted_at == blk_req_2.inserted_at
  end

  test "delete_blocks_from_ppl() deletes all blocks for given ppl and all related structures from DB", ctx  do
    ppl_id = UUID.uuid4()
    assert {:ok, block_id_1} = insert_block(ppl_id, 0, ctx)
    assert {:ok, block_id_2} = insert_block(ppl_id, 1, ctx)

    assert {:ok, _} = BlockRequestsQueries.delete_blocks_from_ppl(ppl_id)

    assert_block_deleted(block_id_1)
    assert_block_deleted(block_id_2)
  end

  defp assert_block_deleted(block_id) do
    assert {:error, {:block_request_not_found, block_id}} == BlockRequestsQueries.get_by_id(block_id)
    assert {:error, {:block_not_found, block_id}} == BlocksQueries.get_by_id(block_id)
    assert {:error, message} = TasksQueries.get_by_id(block_id)
    assert message == "Task for block with id: #{block_id} not found"
    assert {:error, message} = BlockSubpplsQueries.get_all_by_id(block_id)
    assert message == "no subppl's for block with id: #{block_id} found"
  end

  defp insert_block(ppl_id, block_index, ctx) do
    request = %{ppl_id: ppl_id, pple_block_index: block_index, request_args: ctx.request_args,
                definition: ctx.definition_v3, version: "v3.0", hook_id: UUID.uuid4()}
    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)

    assert {:ok, _} = BlocksQueries.insert(blk_req)
    assert {:ok, _} = insert_task(blk_req)
    assert {:ok, _} = insert_subppl(blk_req)
    {:ok, blk_req.id}
  end

  defp insert_task(blk_req) do
    Multi.new()
    |> TasksQueries.multi_insert(blk_req)
    |> Repo.transaction
  end

  defp insert_subppl(blk_req) do
    Multi.new()
    |> BlockSubpplsQueries.multi_insert(blk_req, {"subppl.yml", 0})
    |> Repo.transaction
  end

  test "duplicate blk_req", ctx do
    definition = Map.get(ctx, :definition_v3)
    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: ctx.request_args,
                definition: definition, version: "v3.0", hook_id: UUID.uuid4()}

    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: definition |> Map.get("build")})

    new_ppl_id =  UUID.uuid4()
    assert {:ok, duplicate} = BlockRequestsQueries.duplicate(blk_req.id, new_ppl_id)
    assert duplicate.id != blk_req.id
    assert duplicate.ppl_id == new_ppl_id
    different_fields = [:id, :ppl_id, :inserted_at, :updated_at]
    assert duplicate |> Map.drop(different_fields) == blk_req |> Map.drop(different_fields)
  end

  test "get by id", ctx do
    test_get_by_id(:v1, UUID.uuid4(), 0, ctx)
    test_get_by_id(:v3, UUID.uuid4(), 0, ctx)
  end

  defp test_get_by_id(version, ppl_id, index, ctx) do
    {:ok, args} = Map.fetch(ctx, :request_args)
    request = %{ppl_id: ppl_id, pple_block_index: index, request_args: args,
                hook_id: UUID.uuid4()}

    request = to_version(version, request, ctx)
    assert_test_get_by_id(request)
  end

  defp assert_test_get_by_id(request) do
    assert {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    assert {:ok, response} = BlockRequestsQueries.get_by_id(blk_req.id)
    assert response.id == blk_req.id
  end

  defp to_version(:v1, request, ctx), do: v1_request(request, ctx)
  defp to_version(:v3, request, ctx), do: v3_request(request, ctx)

  defp v1_request(request, ctx) do
    {:ok, definition} = Map.fetch(ctx, :definition_v1)
    request = Map.put(request, :version, "v1.0")
    Map.put(request, :definition, definition)
  end

  defp v3_request(request, ctx) do
    {:ok, definition} = Map.fetch(ctx, :definition_v3)
    request = Map.put(request, :version, "v3.0")
    Map.put(request, :definition, definition)
  end

  test "get by ppl data - success", ctx do
    test_get_by_ppl_data(:v1, UUID.uuid4(), 0, ctx)
    test_get_by_ppl_data(:v3, UUID.uuid4(), 0, ctx)
  end

  defp test_get_by_ppl_data(version, ppl_id, index, ctx) do
    {:ok, args} = Map.fetch(ctx, :request_args)
    request = %{ppl_id: ppl_id, pple_block_index: index, request_args: args,
                hook_id: UUID.uuid4()}

    request = to_version(version, request, ctx)
    make_assertions(request, ppl_id, index)
  end

  defp make_assertions(request, ppl_id, index) do
    assert {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    assert {:ok, response} = BlockRequestsQueries.get_by_ppl_data(ppl_id, index)
    assert response.id == blk_req.id
  end

  test "get by ppl data - failure: not found", _ctx do
    ppl_id = UUID.uuid4()
    index = 0
    assert {:error, reason} = BlockRequestsQueries.get_by_ppl_data(ppl_id, index)
    assert {:block_not_found, ppl_id, index} == reason
  end
end
