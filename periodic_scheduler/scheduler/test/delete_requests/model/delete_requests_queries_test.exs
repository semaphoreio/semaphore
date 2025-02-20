defmodule Scheduler.DeleteRequests.Model.DeleteRequestsQueries.Test do
  use ExUnit.Case

  alias Scheduler.DeleteRequests.Model.DeleteRequestsQueries

  setup do
    Test.Helpers.truncate_db()
    :ok
  end

  test "insert new DeleteRequest with only id - success" do
    params = default_params() |> Map.merge(%{id: UUID.uuid4(), requester: UUID.uuid4()})

    assert {:ok, del_req} = DeleteRequestsQueries.insert(params)
    assert del_req.periodic_id == params.id
    assert del_req.requester == params.requester
    assert del_req.periodic_name == ""
    assert del_req.organization_id == ""
  end

  test "insert new DeleteRequest with out periodic identifiers - fail" do
    params = default_params() |> Map.merge(%{requester_id: UUID.uuid4()})

    assert {:error, _msg} = DeleteRequestsQueries.insert(params)
  end

  test "insert new DeleteRequest without requester_id - fail" do
    params =
      default_params()
      |> Map.merge(%{name: "P1", organization_id: UUID.uuid4(), id: UUID.uuid4()})

    assert {:error, _msg} = DeleteRequestsQueries.insert(params)
  end

  defp default_params() do
    %{
      id: "",
      name: "",
      organization_id: "",
      requester: ""
    }
  end
end
