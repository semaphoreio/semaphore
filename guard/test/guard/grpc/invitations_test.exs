defmodule Guard.Grpc.InvitationsTest do
  use Guard.RepoCase

  alias Guard.FrontRepo
  alias Guard.FrontRepo.{Member, RepoHostAccount, User}
  alias InternalApi.Guard.InvitationsRequest, as: Request

  setup do
    FrontRepo.delete_all(Member)
    FrontRepo.delete_all(RepoHostAccount)
    FrontRepo.delete_all(User)

    org = Support.Factories.organization()

    org_id = org.org_id

    {:ok, _} = Support.Members.insert_member(organization_id: org_id)
    {:ok, member} = Support.Members.insert_member(organization_id: org_id)
    {:ok, user} = Support.Members.insert_user(name: "John")

    {:ok, _} =
      Support.Members.insert_repo_host_account(
        login: "john",
        github_uid: member.github_uid,
        user_id: user.id,
        repo_host: member.repo_host
      )

    [
      org_id: org_id
    ]
  end

  describe "invitations" do
    test "returns invitations", %{org_id: org_id} do
      Support.Factories.Organization.insert!(id: org_id)

      {:ok, response} = Request.new(org_id: org_id) |> make_request()

      assert Enum.count(response.invitations) == 1
    end

    test "returns empty list" do
      org_id = Ecto.UUID.generate()
      Support.Factories.Organization.insert!(id: org_id)

      {:ok, response} = Request.new(org_id: org_id) |> make_request()

      assert Enum.empty?(response.invitations)
    end

    test "returns an error if organization doesn't exist" do
      response =
        Request.new(org_id: Ecto.UUID.generate())
        |> make_request()

      assert {:error, %GRPC.RPCError{message: "Organization not found", status: 5}} = response
    end
  end

  defp make_request(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    InternalApi.Guard.Guard.Stub.invitations(channel, request)
  end
end
