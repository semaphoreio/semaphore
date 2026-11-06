defmodule Ppl.WorkflowActions.Test do
  use ExUnit.Case

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.WorkflowActions

  setup do
    Test.Helpers.truncate_db()

    params = Test.Helpers.schedule_request_factory(%{}, :github)
    {:ok, req} = PplRequestsQueries.insert_request(params)
    {:ok, %{req: req}}
  end

  describe "get_frist_ppl_artefact_id/1" do
    test "first_ppl_id resolves to the pipeline's own artefact id", %{req: req} do
      assert {:ok, artefact_id} = WorkflowActions.get_frist_ppl_artefact_id(%{first_ppl_id: req.id})
      assert artefact_id == req.ppl_artefact_id
    end

    test "last_ppl_id resolves through wf_id to the initial pipeline's artefact id", %{req: req} do
      assert {:ok, artefact_id} = WorkflowActions.get_frist_ppl_artefact_id(%{last_ppl_id: req.id})
      assert artefact_id == req.ppl_artefact_id
    end

    test "unknown first_ppl_id is not resolved" do
      assert {:error, _} =
               WorkflowActions.get_frist_ppl_artefact_id(%{first_ppl_id: UUID.uuid4()})
    end
  end
end
