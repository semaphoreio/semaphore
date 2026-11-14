defmodule RepositoryHub.ServiceAccountClientTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias InternalApi.ServiceAccount.{DescribeResponse, ServiceAccount, SetOwnerRequest}

  # The owner rule reads these fields off the wire. A generated module that does not carry
  # them still compiles here, and would then refuse every service account, so what the
  # rule depends on is pinned rather than found out in production.
  describe "the generated service account messages" do
    test "name the owner an account acts for" do
      assert %ServiceAccount{owner_id: "", owner_active: false} = %ServiceAccount{}
    end

    test "name the member making a set owner request" do
      assert %SetOwnerRequest{requester_id: ""} = %SetOwnerRequest{}
    end

    test "carry the owner through a round trip on the wire" do
      response = %DescribeResponse{
        service_account: %ServiceAccount{owner_id: "an-owner-id", owner_active: true}
      }

      decoded =
        response
        |> DescribeResponse.encode()
        |> DescribeResponse.decode()

      assert %{service_account: %{owner_id: "an-owner-id", owner_active: true}} = decoded
    end
  end
end
