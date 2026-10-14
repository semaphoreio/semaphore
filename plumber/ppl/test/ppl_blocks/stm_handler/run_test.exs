defmodule Ppl.PplBlocks.STMHandler.WaitingState.Test do
  use ExUnit.Case, async: false

  import Mock

  alias Ppl.PplBlocks.Model.{PplBlocks, PplBlocksQueries}
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplBlocks.STMHandler.WaitingState
  alias Ppl.DefinitionReviser
  alias Ppl.PplBlocks.Model.PplBlockConectionsQueries
  alias Ppl.Actions

  setup do
    Test.Helpers.truncate_db()

    assert {:ok, %{ppl_id: ppl_id}} =
      %{"requester_id" => ""}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    assert {:ok, ppl_req} = PplRequestsQueries.get_by_id(ppl_id)

    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    task = %{"jobs" => jobs_list}
    agent = %{"machine" => %{"type" => "foo", "os_image" => "bar"}}
    definition = %{"version" => "v1.0", "agent" => agent, "name" => "Test Pipeline",
      "blocks" => [%{"name" => "blk 0", "task" => task},
        %{"name" => "blk 1", "task" => task}]}

    {:ok, definition} = DefinitionReviser.revise_definition(definition, ppl_req)
    {:ok, ppl_req} = PplRequestsQueries.insert_definition(ppl_req, definition)

    {:ok, %{ppl_id: ppl_id, ppl_req: ppl_req}}
  end

  test "PplBlocks run looper runs block without dependencies", ctx do
    ppl_id = Map.get(ctx, :ppl_id)
    workflow_id = ctx.ppl_req.wf_id

    assert {:ok, ppl_blk} = insert_ppl_blk(ppl_id, 0)
    assert ppl_blk.state == "waiting"

    with_mock Block, [schedule: &(mocked_schedule({&1, ppl_id, workflow_id, ctx.ppl_req.request_args, ppl_blk.name})),
                      status: &mocked_status(&1)] do
      assert {:ok, result_func} = WaitingState.scheduling_handler(ppl_blk)

      assert is_function(result_func)
      assert {:ok, %{state: "running", block_id: block_id}} = result_func.(:repo, :changes)
      assert {:ok, _} = UUID.info(block_id)
    end
  end

  test "PplBlocks run looper runs block if dependency passed", ctx do
    ppl_id = Map.get(ctx, :ppl_id)
    workflow_id = ctx.ppl_req.wf_id

    assert {:ok, _previous} = prepare_done_block_with_result(ppl_id, "passed")

    assert {:ok, ppl_blk} = insert_ppl_blk(ppl_id, 1)
    assert ppl_blk.state == "waiting"

    insert_connections(ctx.ppl_req)

    with_mock Block, [schedule: &(mocked_schedule({&1, ppl_id, workflow_id, ctx.ppl_req.request_args, ppl_blk.name})),
                      status: &mocked_status(&1)] do
      assert {:ok, result_func} = WaitingState.scheduling_handler(ppl_blk)

      assert is_function(result_func)
      assert {:ok, %{state: "running", block_id: block_id}} = result_func.(:repo, :changes)
      assert {:ok, _} = UUID.info(block_id)
    end
  end

  test "PplBlocks run looper cancels block if dependency failed", ctx do
    ppl_id = Map.get(ctx, :ppl_id)
    workflow_id = ctx.ppl_req.wf_id

    assert {:ok, _previous} = prepare_done_block_with_result(ppl_id, "failed")

    assert {:ok, ppl_blk} = insert_ppl_blk(ppl_id, 1)
    assert ppl_blk.state == "waiting"

    insert_connections(ctx.ppl_req)

    with_mock Block, [schedule: &(mocked_schedule({&1, ppl_id, workflow_id, ctx.ppl_req.request_args, ppl_blk.name})),
                      status: &mocked_status(&1)] do
      assert {:ok, result_func} = WaitingState.scheduling_handler(ppl_blk)

      assert is_function(result_func)
      assert {:ok, %{state: "done", result: "canceled"}} = result_func.(:repo, :changes)
    end
  end

  defp insert_connections(ppl_req) do
    Ecto.Multi.new()
    |> PplBlockConectionsQueries.multi_insert(ppl_req)
    |> Repo.transaction
  end

  def query_params() do
    %{initial_query: Ppl.PplBlocks.Model.PplBlocks, cooling_time_sec: -2,
      repo: Ppl.EctoRepo, schema: Ppl.PplBlocks.Model.PplBlocks, returning: [:id, :ppl_id],
      allowed_states: ~w(waiting running stopping done)}
  end

  def to_state(ppl_blk, state, additional \\ %{}) do
    args = query_params()
    Looper.STM.Impl.exit_scheduling(ppl_blk, fn _, _ -> {:ok, Map.merge(additional, %{state: state})} end, args)
    PplBlocksQueries.get_by_id_and_index(ppl_blk.ppl_id, ppl_blk.block_index)
  end

  defp prepare_done_block_with_result(ppl_id, result) do
    assert {:ok, ppl_blk} = insert_ppl_blk(ppl_id, 0)
    assert ppl_blk.state == "waiting"

    assert {:ok, ppl_blk} = to_state(ppl_blk, "done", %{result: result})
    assert ppl_blk.result == result
    {:ok, ppl_blk}
  end

  defp mocked_schedule({schedule_request, id, workflow_id, req_args, blk_name}) do
    assert schedule_request.ppl_id == id
    assert get_in(schedule_request.definition, ["build", "agent", "machine"]) == %{"os_image" => "bar", "type" => "foo"}
    ppl_env_vars = [%{"name" => "SEMAPHORE_WORKFLOW_ID", "value" => "#{workflow_id}"},
                    %{"name" => "SEMAPHORE_WORKFLOW_NUMBER", "value" => "1"},
                    %{"name" => "SEMAPHORE_WORKFLOW_RERUN", "value" => "false"},
                    %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK", "value" => "true"},
                    %{"name" => "SEMAPHORE_WORKFLOW_HOOK_SOURCE", "value" => "github"},
                    %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE", "value" => "false"},
                    %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API", "value" => "false"},
                    %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN", "value" => "false"},
                    %{"name" => "SEMAPHORE_PIPELINE_ARTEFACT_ID", "value" => "#{id}"},
                    %{"name" => "SEMAPHORE_PIPELINE_ID", "value" => "#{id}"},
                    %{"name" => "SEMAPHORE_PIPELINE_NAME", "value" => "Test Pipeline"},
                    %{"name" => "SEMAPHORE_BLOCK_NAME", "value" => blk_name},
                    %{"name" => "SEMAPHORE_PIPELINE_RERUN", "value" => "false"},
                    %{"name" => "SEMAPHORE_PIPELINE_PROMOTION", "value" => "false"},
                    %{"name" => "SEMAPHORE_PIPELINE_PROMOTED_BY", "value" => ""},
                    %{"name" => "SEMAPHORE_WORKFLOW_TRIGGERED_BY", "value" => ""},
                    %{"name" => "SEMAPHORE_GIT_COMMIT_AUTHOR", "value" => ""},
                    %{"name" => "SEMAPHORE_GIT_COMMITTER", "value" => ""},
                    %{"name" => "SEMAPHORE_ORGANIZATION_ID", "value" => req_args["organization_id"]},
                    %{"name" => "SEMAPHORE_PIPELINE_0_ARTEFACT_ID", "value" => "#{id}"}]
    assert get_in(schedule_request.definition, ["build", "ppl_env_variables"]) == ppl_env_vars
    {:ok, UUID.uuid4()}
  end

  defp mocked_status(_block_id) do
    %{inserted_at: DateTime.utc_now()}
  end

  defp insert_ppl_blk(ppl_id, block_index) do
    params = %{ppl_id: ppl_id, block_index: block_index}
      |> Map.put(:state, "waiting")
      |> Map.put(:in_scheduling, "false")
      |> Map.put(:name, "blk #{inspect(block_index)}")

    %PplBlocks{} |> PplBlocks.changeset(params) |> Repo.insert
  end

end
