defmodule Front.Models.MemberTest do
  use ExUnit.Case

  alias Front.Models.Member
  alias Support.Stubs.DB

  setup do
    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    organization = DB.first(:organizations)
    user = DB.first(:users)

    [
      org_id: organization.id,
      user_id: user.id
    ]
  end

  describe ".invite" do
    test "when the response is succesfull for github => it returns an ok response with the member",
         %{
           org_id: org_id,
           user_id: user_id
         } do
      invitee_data = %{
        "invite_email" => "",
        "username" => "radwo",
        "uid" => "184065",
        "provider" => "github"
      }

      invitee =
        InternalApi.Guard.Invitee.new(
          email: "",
          name: "",
          provider:
            InternalApi.User.RepositoryProvider.new(
              login: "radwo",
              uid: "184065",
              type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB)
            )
        )

      assert Member.invite([invitee_data], org_id, user_id) == {:ok, [invitee]}
    end

    test "when the response is succesfull for gitlab => it returns an ok response with the member",
         %{
           org_id: org_id,
           user_id: user_id
         } do
      invitee_data = %{
        "invite_email" => "",
        "username" => "generic_user",
        "uid" => "111111",
        "provider" => "gitlab"
      }

      invitee =
        InternalApi.Guard.Invitee.new(
          email: "",
          name: "",
          provider:
            InternalApi.User.RepositoryProvider.new(
              login: "generic_user",
              uid: "111111",
              type: InternalApi.User.RepositoryProvider.Type.value(:GITLAB)
            )
        )

      assert Member.invite([invitee_data], org_id, user_id) == {:ok, [invitee]}
    end

    test "when the response is unsuccesfull for github => it returns an error response", %{
      org_id: org_id,
      user_id: user_id
    } do
      invitee_data = %{
        "invite_email" => "",
        "username" => "radwo",
        "uid" => "184065",
        "provider" => "github"
      }

      GrpcMock.stub(GuardMock, :invite_collaborators, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "Invalid"
      end)

      {:error, error} = Member.invite([invitee_data], org_id, user_id)

      assert error == "Invalid"
    end

    test "when the response is unsuccesfull for gitlab => it returns an error response", %{
      org_id: org_id,
      user_id: user_id
    } do
      invitee_data = %{
        "invite_email" => "",
        "username" => "generic_user",
        "uid" => "111111",
        "provider" => "gitlab"
      }

      GrpcMock.stub(GuardMock, :invite_collaborators, fn _, _ ->
        raise GRPC.RPCError, status: 3, message: "Invalid"
      end)

      {:error, error} = Member.invite([invitee_data], org_id, user_id)

      assert error == "Invalid"
    end
  end

  describe ".destroy" do
    test "when the response is succesfull => it returns an ok response" do
      response =
        InternalApi.Organization.DeleteMemberResponse.new(
          status: Google.Rpc.Status.new(code: Google.Rpc.Code.value(:OK))
        )

      GrpcMock.stub(OrganizationMock, :delete_member, fn req, _stream ->
        assert req.membership_id == "123"
        assert req.org_id == "321"

        response
      end)

      assert Member.destroy("321", membership_id: "123") == {:ok, true}
    end

    test "when the response is unsuccesfull => it returns an error response" do
      response =
        InternalApi.Organization.DeleteMemberResponse.new(
          status:
            Google.Rpc.Status.new(
              code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
              message: "Oops"
            )
        )

      GrpcMock.stub(OrganizationMock, :delete_member, response)

      assert Member.destroy("123", user_id: "321") == {:error, "Oops"}
    end
  end
end
