defmodule Ppl.DeleteRequests.Model.DeleteRequestsQueries.Test do
  use ExUnit.Case

  alias Ppl.DeleteRequests.Model.{DeleteRequests, DeleteRequestsQueries}
  
  setup do
    Test.Helpers.truncate_db()
    
    {:ok, %{}}
  end
  
  test "insert delete_request" do
    assert {:ok, pdr = %DeleteRequests{}} =
      %{project_id: UUID.uuid4, requester: UUID.uuid4()} |> DeleteRequestsQueries.insert()
      
    assert pdr.state == "pending"
    assert pdr.in_scheduling == false
    assert pdr.recovery_count == 0
  end
  
  test "project_deletion_requested? returns true if project's pipelines deletion is requested" do
    project_id = UUID.uuid4
    assert {:ok, %DeleteRequests{}} =
      %{project_id: project_id, requester: UUID.uuid4()} |> DeleteRequestsQueries.insert()
      
    assert {:ok, true} == DeleteRequestsQueries.project_deletion_requested?(project_id)
  end
  
  test "project_deletion_requested? returns false if project's pipelines deletion is not requested" do
    project_id = "non-existing-id"
      
    assert {:ok, false} == DeleteRequestsQueries.project_deletion_requested?(project_id)
  end
end