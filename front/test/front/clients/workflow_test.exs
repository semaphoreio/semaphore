defmodule Front.Clients.WorkflowTest do
  use FrontWeb.ConnCase

  import Mock

  alias Front.Clients.Workflow
  alias InternalApi.PlumberWF.ListKeysetRequest

  describe ".list_keyset" do
    test "returns ListKeysetResponse for ListKeysetRequest" do
      request = ListKeysetRequest.new()

      assert {:ok, %InternalApi.PlumberWF.ListKeysetResponse{}} = Workflow.list_keyset(request)
    end

    test "returns an error when grpc connection times out" do
      request = ListKeysetRequest.new()

      with_mock GRPC.Stub, [:passthrough],
        connect: fn _ -> {:error, "Error when opening connection: :timeout"} end do
        assert {:error, "Error when opening connection: :timeout"} = Workflow.list_keyset(request)
      end
    end
  end
end
