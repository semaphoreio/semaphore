defmodule Ppl.PplRequests.Model.PplRequestsQueries.Test do
  use ExUnit.Case
  doctest Ppl.PplRequests.Model.PplRequestsQueries

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries
  alias Ppl.PplBlocks.Model.{PplBlocksQueries, PplBlockConectionsQueries, PplBlockConnections}
  alias Ppl.PplTraces.Model.{PplTracesQueries, PplTracesQueries}
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias Ppl.EctoRepo, as: Repo
  alias Ecto.Multi

  setup do
    Test.Helpers.truncate_db()

    request = Test.Helpers.schedule_request_factory(:local)

    {:ok, %{request: request}}
  end

  test "latest_ppl_from_subtree()", ctx do

    # Creates workflow with this topology:
    #
    #       4 -> 8       single arrow: extension (promotion)
    #       ⇈            double arrow: partial rebuild
    #       2 -> 6       pipelines are enumerated by order of creation
    #     ↗
    #   ↗
    # 1
    #   ↘        7
    #     ↘      ⇈
    #       3 -> 5
    #

    assert {:ok, ppl_req_1} = PplRequestsQueries.insert_request(ctx.request, true, true)
    assert {:ok, ppl_1} = PplsQueries.insert(ppl_req_1)

    assert {:ok, ppl_req_1} == PplRequestsQueries.latest_ppl_from_subtree(ppl_1.ppl_id)

    assert {:ok, ppl_req_2, ppl_2} = insert_extension(ppl_req_1, ppl_1.ppl_id, 2)
    assert {:ok, ppl_req_2} == PplRequestsQueries.latest_ppl_from_subtree(ppl_1.ppl_id)
    assert {:ok, ppl_req_2} == PplRequestsQueries.latest_ppl_from_subtree(ppl_2.ppl_id)

    assert {:ok, ppl_req_3, ppl_3} = insert_extension(ppl_req_1, ppl_1.ppl_id, 3)
    assert {:ok, ppl_req_3} == PplRequestsQueries.latest_ppl_from_subtree(ppl_1.ppl_id)
    assert {:ok, ppl_req_2} == PplRequestsQueries.latest_ppl_from_subtree(ppl_2.ppl_id)
    assert {:ok, ppl_req_3} == PplRequestsQueries.latest_ppl_from_subtree(ppl_3.ppl_id)

    assert {:ok, ppl_req_4, ppl_4} = insert_partial_rebuild(ppl_2.ppl_id)
    assert {:ok, ppl_req_4} == PplRequestsQueries.latest_ppl_from_subtree(ppl_1.ppl_id)
    assert {:ok, ppl_req_2} == PplRequestsQueries.latest_ppl_from_subtree(ppl_2.ppl_id)
    assert {:ok, ppl_req_3} == PplRequestsQueries.latest_ppl_from_subtree(ppl_3.ppl_id)

    assert {:ok, ppl_req_5, ppl_5} = insert_extension(ppl_req_3, ppl_3.ppl_id, 5)
    assert {:ok, ppl_req_5} == PplRequestsQueries.latest_ppl_from_subtree(ppl_1.ppl_id)
    assert {:ok, ppl_req_2} == PplRequestsQueries.latest_ppl_from_subtree(ppl_2.ppl_id)
    assert {:ok, ppl_req_5} == PplRequestsQueries.latest_ppl_from_subtree(ppl_3.ppl_id)

    assert {:ok, ppl_req_6, _ppl_6} = insert_extension(ppl_req_2, ppl_2.ppl_id, 6)
    assert {:ok, ppl_req_6} == PplRequestsQueries.latest_ppl_from_subtree(ppl_1.ppl_id)
    assert {:ok, ppl_req_6} == PplRequestsQueries.latest_ppl_from_subtree(ppl_2.ppl_id)
    assert {:ok, ppl_req_5} == PplRequestsQueries.latest_ppl_from_subtree(ppl_3.ppl_id)

    assert {:ok, ppl_req_7, _ppl_7} = insert_partial_rebuild(ppl_5.ppl_id)
    assert {:ok, ppl_req_7} == PplRequestsQueries.latest_ppl_from_subtree(ppl_1.ppl_id)
    assert {:ok, ppl_req_6} == PplRequestsQueries.latest_ppl_from_subtree(ppl_2.ppl_id)
    assert {:ok, ppl_req_7} == PplRequestsQueries.latest_ppl_from_subtree(ppl_3.ppl_id)

    assert {:ok, ppl_req_8, _ppl_8} = insert_extension(ppl_req_4, ppl_4.ppl_id, 8)
    assert {:ok, ppl_req_8} == PplRequestsQueries.latest_ppl_from_subtree(ppl_1.ppl_id)
    assert {:ok, ppl_req_6} == PplRequestsQueries.latest_ppl_from_subtree(ppl_2.ppl_id)
    assert {:ok, ppl_req_7} == PplRequestsQueries.latest_ppl_from_subtree(ppl_3.ppl_id)

    assert {:ok, [elem_1, elem_2, elem_3]} =
      Ppl.WorkflowActions.find_path(ppl_req_1.ppl_artefact_id, ppl_req_8)

    assert elem_1 == %{ppl_id: ppl_req_1.id, rebuild_partition: [ppl_req_1.id],
                       switch_id: ""}
    assert elem_2 == %{ppl_id: ppl_req_4.id, rebuild_partition: [ppl_req_2.id, ppl_req_4.id],
                       switch_id: ""}
    assert elem_3 == %{ppl_id: ppl_req_8.id, rebuild_partition: [ppl_req_8.id],
                       switch_id: ""}
  end

  def insert_extension(request, ppl_id, index) do
    assert {:ok, ppl_req_ext} =
     request.request_args
      |> update_previous_artefact_ids(request)
      |> Map.merge(%{"request_token" => UUID.uuid4, "extension_of" => ppl_id,
                      "wf_id" => request.wf_id, "no" => index})
      |> PplRequestsQueries.insert_request(true, false)

    assert {:ok, ppl_ext} = PplsQueries.insert(ppl_req_ext)
    {:ok, ppl_req_ext, ppl_ext}
  end

  defp update_previous_artefact_ids(args, request) do
    previous_ids = request.prev_ppl_artefact_ids ++ [request.ppl_artefact_id]
    args |> Map.put("prev_ppl_artefact_ids", previous_ids)
  end

  defp insert_partial_rebuild(ppl_id) do
    assert {:ok, ppl_req_rbd} = PplRequestsQueries.duplicate(ppl_id, UUID.uuid4(), UUID.uuid4())
    assert {:ok, ppl_rbd} = PplsQueries.insert(ppl_req_rbd, ppl_id)
    {:ok, ppl_req_rbd, ppl_rbd}
  end

  test "insert pipeline request", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    {:ok, request_token} = Map.fetch(request, "request_token")
    request_args = request |> Map.drop(["request_token", "wf_id"])

    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    assert ppl_req.request_args == request_args
    assert ppl_req.request_token == request_token
    assert ppl_req.block_count == 0
  end

  test "can not insert pipeline request without request_token", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    request = Map.delete(request, "request_token")

    assert {:error, _message} = PplRequestsQueries.insert_request(request)
  end

  test "cannot insert 2 pipeline requests with the same request_token", ctx do
    {:ok, request} = Map.fetch(ctx, :request)

    assert {:ok, _ppl_req_1} = PplRequestsQueries.insert_request(request, true, true)
    assert({:error, {:request_token_exists, _}} =
      PplRequestsQueries.insert_request(request, true, true))
  end

  test "delete_pipeline() deletes pipeline and all other related structures", ctx do
    assert {:ok, ppl_req} = insert_ppl_req(ctx)
    assert {:ok, ppl} = PplsQueries.insert(ppl_req)
    assert {:ok, _}   = create_ppl_blocks(ppl_req)
    assert {:ok, _pp} = PplOriginsQueries.insert(ppl.ppl_id, %{a: 1})
    assert {:ok, _psi} = PplSubInitsQueries.insert(ppl_req, "regular")
    assert {:ok, _pt} = PplTracesQueries.insert(ppl)

    assert {:ok, 1} = PplRequestsQueries.delete_pipeline(ppl.ppl_id)

    assert {:error, _e} = PplRequestsQueries.get_by_id(ppl.ppl_id)
    assert {:error, _e} = PplsQueries.get_by_id(ppl.ppl_id)
    assert {:error, _e} = PplBlocksQueries.get_all_by_id(ppl.ppl_id)
    assert [] == PplBlockConnections |> Repo.all()
    assert {:error, _e} = PplOriginsQueries.get_by_id(ppl.ppl_id)
    assert {:error, _e} = PplSubInitsQueries.get_by_id(ppl.ppl_id)
    assert {:error, _e} = PplTracesQueries.get_by_id(ppl.ppl_id)
  end

  defp insert_ppl_req(ctx) do
    job_1 = %{"name" => "job1", "commands" => ["echo foo", "echo bar"]}
    job_2 = %{"name" => "job2", "commands" => ["echo baz"]}
    jobs_list = [job_1, job_2]
    build = %{"jobs" => jobs_list}

    blocks = [%{"name" => "b1", "build" => build, "dependencies" => []},
              %{"name" => "b2", "build" => build, "dependencies" => ["b1"]}]
    agent = %{"machine" => %{"type" => "e1-standard-2", "os_image" => "ubuntu1804"}}
    definition = %{"version" => "v1.0", "agent" => agent, "blocks" => blocks}

    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(ctx.request)
    PplRequestsQueries.insert_definition(ppl_req, definition)
  end

  defp create_ppl_blocks(ppl_req) do
    Multi.new
    |> PplBlocksQueries.multi_insert(ppl_req)
    |> PplBlockConectionsQueries.multi_insert(ppl_req)
    |> Repo.transaction()
  end

  test "get by id", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    assert {:ok, ppl_req} = PplRequestsQueries.insert_request(request)
    id = ppl_req.id

    assert {:ok, response} = PplRequestsQueries.get_by_id(id)
    assert response.id == id
  end

  test "get by request_token - success", ctx do
    {:ok, request} = Map.fetch(ctx, :request)
    assert {:ok, _ppl_req} = PplRequestsQueries.insert_request(request)
    {:ok, request_token} = Map.fetch(request, "request_token")

    assert {:ok, response} = PplRequestsQueries.get_by_request_token(request_token)
    assert response.request_token == request_token
  end

  test "get by request_token - failure: not found", _ctx do
    request_token = UUID.uuid4()
    assert {:error, reason} = PplRequestsQueries.get_by_request_token(request_token)
    assert {:request_token_not_found, request_token} == reason
  end
end
