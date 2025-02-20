defmodule Block.Blocks.Beholder.Test do
  use ExUnit.Case

  alias Block.Blocks.Beholder
  alias Block.BlockRequests.Model.BlockRequestsQueries
  alias Block.Blocks.Model.{Blocks, BlocksQueries}
  alias Block.EctoRepo, as: Repo

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Block.EctoRepo, "truncate table block_requests cascade;")

    args = %{"service" => "local", "repo_name" => "2_basic"}
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    build = %{"agent" => agent, "jobs" => jobs_list}
    includes = ["subpipeline_1.yml", "subpipeline_2.yml"]
    definition = %{"build" => build, "includes" => includes}

    request = %{ppl_id: UUID.uuid4(), pple_block_index: 0, request_args: args,
                definition: definition, version: "v3.0", hook_id: UUID.uuid4()}
    {:ok, blk_req} = BlockRequestsQueries.insert_request(request)
    {:ok, blk_req} = BlockRequestsQueries.insert_build(blk_req, %{build: build})

    {:ok, %{blk_req: blk_req, block_id: blk_req.id}}
  end

  test "block is terminated when recovery counter reaches threshold", ctx do
    assert {:ok, blk} = BlocksQueries.insert(ctx.blk_req)
    assert blk.state == "initializing"
    assert {:ok, blk} = blk
      |> Blocks.changeset(%{recovery_count: 5, in_scheduling: true})
      |> Repo.update
    assert blk.recovery_count == 5
    assert blk.in_scheduling == true

    assert {:ok, pid} = Beholder.start_link()
    args = [blk.state, blk, pid]
    Test.Helpers.assert_finished_for_less_than(__MODULE__, :transitioned_to_done, args, 5_000)
  end

  def transitioned_to_done(state, blk, pid) when state != "done" do
    :timer.sleep(100)
    blk = Repo.get(Blocks, blk.id)
    transitioned_to_done(blk.state, blk, pid)
  end
  def transitioned_to_done("done", blk, pid) do
    assert blk.state == "done"
    assert blk.in_scheduling == true
    assert blk.recovery_count == 5
    Process.exit(pid, :normal)
  end

  def query_params() do
    %{initial_query: Block.Blocks.Model.Blocks, cooling_time_sec: -2,
      repo: Block.EctoRepo, schema: Block.Blocks.Model.Blocks, returning: [:id, :block_id],
      allowed_states: ~w(initializing running stopping done)}
  end

  def to_scheduling(state) do
    params = query_params() |> Map.put(:observed_state, state)
    {:ok, %{enter_transition: blk}} = Looper.STM.Impl.enter_scheduling(params)
    {:ok, blk}
  end

  test "recovery counter is incremented when block is recovered from stuck", ctx do
    assert {:ok, looper_pid} = Beholder.start_link()

    assert {:ok, blk} = BlocksQueries.insert(ctx.blk_req)
    assert blk.state == "initializing"
    assert {:ok, blk} = to_scheduling("initializing")
    assert blk.in_scheduling == true

    Test.Helpers.assert_finished_for_less_than(
      __MODULE__, :recovery_count_is_incremented_assert,
      [blk.recovery_count, blk, looper_pid],
      5_000)
  end

  def recovery_count_is_incremented_assert(recovery_count, blk, looper_pid)
  when recovery_count == 0 do
    :timer.sleep(100)
    blk = Repo.get(Blocks, blk.id)

    recovery_count_is_incremented_assert(blk.recovery_count, blk, looper_pid)
  end
  def recovery_count_is_incremented_assert(_recovery_count, blk, looper_pid) do
    assert blk.recovery_count > 0
    Process.exit(looper_pid, :normal)
  end

  test "child_spec accepts 1 arg and returns a map" do
    assert Beholder.child_spec([]) |> is_map()
  end
end
