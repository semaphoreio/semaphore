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

    test "it marks a service account user" do
      user_response =
        InternalApi.User.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          user_id: "12345678-1234-5678-1234-567812345678",
          user: InternalApi.User.User.new(creation_source: :SERVICE_ACCOUNT)
        )

      FunRegistry.set!(Support.FakeServices.UserService, :describe, user_response)

      user = User.find("12345678-1234-5678-1234-567812345678")

      assert user.service_account?
    end

    test "it marks a regular user as not a service account" do
      user_response =
        InternalApi.User.DescribeResponse.new(
          status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          user_id: "12345678-1234-5678-1234-567812345678",
          user: InternalApi.User.User.new(creation_source: :NOT_SET)
        )

      FunRegistry.set!(Support.FakeServices.UserService, :describe, user_response)

      user = User.find("12345678-1234-5678-1234-567812345678")

      refute user.service_account?
    end
  end
end
