defmodule Block.BlockRequests.Model.BlockRequests.Test do
  use ExUnit.Case
  doctest Block.BlockRequests.Model.BlockRequests

  alias Block.BlockRequests.Model.BlockRequests

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    request_args = %{"service" => "local", "repo_name" => "2_basic"}
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}
    definition_v1 = %{"build" => build}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition_v3 = Map.put(definition_v1, "includes", includes)
    {:ok, %{request_args: request_args, definition_v1: definition_v1, definition_v3: definition_v3}}
  end

  # Request changeset

  test "valid request changeset", ctx do
    ppl_id = UUID.uuid4()
    hook_id = UUID.uuid4()
    {:ok, request_args} = Map.fetch(ctx, :request_args)
    changeset = %{ppl_id: ppl_id, pple_block_index: 0, request_args: request_args,
                  hook_id: hook_id}

    changeset_v1 = v1_changeset(changeset, ctx)
    changeset_v3 = v3_changeset(changeset, ctx)

    assert valid?(changeset_v1) == true
    assert get_flags(changeset_v1) == {true, 0}

    assert valid?(changeset_v3) == true
    assert get_flags(changeset_v3) == {true, 2}
  end

  defp v1_changeset(changeset, ctx) do
    {:ok, definition} = Map.fetch(ctx, :definition_v1)
    changeset = Map.put(changeset, :version, "v1.0")
    Map.put(changeset, :definition, definition)
  end

  defp v3_changeset(changeset, ctx) do
    {:ok, definition} = Map.fetch(ctx, :definition_v3)
    changeset = Map.put(changeset, :version, "v3.0")
    Map.put(changeset, :definition, definition)
  end

  defp valid?(changeset) do
     %BlockRequests{} |> BlockRequests.changeset_request(changeset) |> Map.get(:valid?)
  end

  defp get_flags(changeset) do
    changes = %BlockRequests{} |> BlockRequests.changeset_request(changeset) |> Map.get(:changes)

    {Map.get(changes, :has_build?), Map.get(changes, :subppl_count)}
  end

  test "request changeset is invalid without 'ppl_id'", ctx do
    id = UUID.uuid4()
    {:ok, args} = Map.fetch(ctx, :request_args)
    changeset = %{pple_block_index: 0, request_args: args, hook_id: id}

    assert valid?(v1_changeset(changeset, ctx)) == false
    assert valid?(v3_changeset(changeset, ctx)) == false
  end

  test "request changeset is invalid without 'pple_block_index'", ctx do
    ppl_id = UUID.uuid4()
    request_id = UUID.uuid4()
    {:ok, args} = Map.fetch(ctx, :request_args)
    changeset = %{ppl_id: ppl_id, request_args: args, hook_id: request_id}

    assert valid?(v1_changeset(changeset, ctx)) == false
    assert valid?(v3_changeset(changeset, ctx)) == false
  end

  test "request changeset is invalid without 'request_args'", ctx do
    ppl_id = UUID.uuid4()
    request_id = UUID.uuid4()
    changeset = %{ppl_id: ppl_id, pple_block_index: 0, hook_id: request_id}

    assert valid?(v1_changeset(changeset, ctx)) == false
    assert valid?(v3_changeset(changeset, ctx)) == false
  end

  test "request changeset is invalid without 'hook_id'", ctx do
    ppl_id = UUID.uuid4()
    {:ok, args} = Map.fetch(ctx, :request_args)
    changeset = %{pple_block_index: 0, request_args: args, ppl_id: ppl_id}

    assert valid?(v1_changeset(changeset, ctx)) == false
    assert valid?(v3_changeset(changeset, ctx)) == false
  end

  test "request changeset is invalid without 'version'", ctx do
    ppl_id = UUID.uuid4()
    hook_id = UUID.uuid4()
    {:ok, request_args} = Map.fetch(ctx, :request_args)
    changeset = %{ppl_id: ppl_id, pple_block_index: 0, request_args: request_args,
                  hook_id: hook_id}
    changeset_v1 = Map.delete(v1_changeset(changeset, ctx), :version)
    changeset_v3 = Map.delete(v3_changeset(changeset, ctx), :version)

    assert valid?(changeset_v1) == false
    assert valid?(changeset_v3) == false
  end

  test "request changeset is invalid without 'definition'", ctx do
    ppl_id = UUID.uuid4()
    hook_id = UUID.uuid4()
    {:ok, request_args} = Map.fetch(ctx, :request_args)
    changeset = %{ppl_id: ppl_id, pple_block_index: 0, request_args: request_args,
                  hook_id: hook_id}
    changeset_v1 = Map.delete(v1_changeset(changeset, ctx), :definition)
    changeset_v3 = Map.delete(v3_changeset(changeset, ctx), :definition)

    assert valid?(changeset_v1) == false
    assert valid?(changeset_v3) == false
  end

  test "v1 request changeset is invalid with 'definition' without 'build'", ctx do
    ppl_id = UUID.uuid4()
    hook_id = UUID.uuid4()
    {:ok, request_args} = Map.fetch(ctx, :request_args)
    {:ok, definition} = Map.fetch(ctx, :definition_v1)
    definition = Map.delete(definition, "build")
    changeset = %{ppl_id: ppl_id, pple_block_index: 0, request_args: request_args,
                  version: "v1.0", definition: definition, hook_id: hook_id}

    assert valid?(changeset) == false
  end

  test "v1 request changeset is invalid with 'definition' with 'includes'", ctx do
    ppl_id = UUID.uuid4()
    hook_id = UUID.uuid4()
    {:ok, request_args} = Map.fetch(ctx, :request_args)
    {:ok, definition} = Map.fetch(ctx, :definition_v1)
    definition = Map.put(definition, "includes", [])
    changeset = %{ppl_id: ppl_id, pple_block_index: 0, request_args: request_args,
                  version: "v1.0", definition: definition, hook_id: hook_id}

    assert valid?(changeset) == false
  end

  # Build changeset

  test "valid build changeset", ctx do
    {blk_req, definition} = get_blk_req_and_def(ctx)

    {:ok, build} = Map.fetch(definition, "build")
    changeset = %{build: build}

    assert valid_build_cs?(blk_req, changeset) == true
  end

  defp get_blk_req_and_def(ctx) do
    ppl_id = UUID.uuid4()
    hook_id = UUID.uuid4()
    {:ok, request_args} = Map.fetch(ctx, :request_args)
    {:ok, definition} = Map.fetch(ctx, :definition_v3)
    blk_req = %BlockRequests{ppl_id: ppl_id, pple_block_index: 0, request_args: request_args,
                             version: "v3.0", definition: definition, hook_id: hook_id}
    {blk_req, definition}
  end

  defp valid_build_cs?(blk_req, changeset) do
     blk_req |> BlockRequests.changeset_build(changeset) |> Map.get(:valid?)
  end

  test "build changeset is invalid without 'build' field", ctx do
    {blk_req, _definition} = get_blk_req_and_def(ctx)

    changeset = %{}

    assert valid_build_cs?(blk_req, changeset) == false
  end

end
