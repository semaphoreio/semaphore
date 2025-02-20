defmodule Projecthub.Models.UserTest do
  use Projecthub.DataCase
  alias Projecthub.Models.User

  describe ".find" do
    test "it fetches the user with correct params" do
      user_response =
        InternalApi.User.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          user_id: "12345678-1234-5678-1234-567812345678"
        )

      FunRegistry.set!(Support.FakeServices.UserService, :describe, fn req, _stream ->
        assert req.user_id == "12345678-1234-5678-1234-567812345678"

        user_response
      end)

      assert User.find("12345678-1234-5678-1234-567812345678")
    end
  end
end
