defmodule Guard.Grpc.InviteCollaboratorsTest do
  use Guard.RepoCase
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias InternalApi.Guard.InviteCollaboratorsRequest, as: Request
  alias Support.Members, as: MembersSupport

  import Mock

  setup do
    Guard.FrontRepo.delete_all(Guard.FrontRepo.Member)

    FunRegistry.clear!()
    Guard.FakeServers.setup_responses_for_development()

    org = Support.Factories.organization()
    user = Support.Factories.user()

    status = Support.Factories.status_ok()

    FunRegistry.set!(
      Support.Fake.OrganizationService,
      :describe,
      InternalApi.Organization.DescribeResponse.new(
        status: status,
        organization: org
      )
    )

    FunRegistry.set!(
      Support.Fake.UserService,
      :describe,
      InternalApi.User.DescribeResponse.new(
        status: status,
        organization: org
      )
    )

    org_id = org.org_id
    user_id = user.user_id

    [
      org_id: org_id,
      user_id: user_id
    ]
  end

  describe "invite_collaborators" do
    test "returns error for invalid input", %{org_id: org_id, user_id: user_id} do
      Support.Factories.Organization.insert!(id: org_id)

      invitees = [
        InternalApi.Guard.Invitee.new(
          email: "",
          name: "",
          provider: InternalApi.User.RepositoryProvider.new()
        )
      ]

      assert {:error, %GRPC.RPCError{status: 9, message: "empty login not allowed"}} =
               Request.new(inviter_id: user_id, org_id: org_id, invitees: invitees)
               |> make_request()
    end

    test "returns invitees after adding them", %{org_id: org_id, user_id: user_id} do
      Support.Factories.Organization.insert!(id: org_id)

      use_cassette "existing user" do
        {:ok, user} =
          MembersSupport.insert_user(
            name: "John",
            blocked_at: DateTime.utc_now() |> DateTime.truncate(:second)
          )

        {:ok, _} =
          MembersSupport.insert_repo_host_account(
            login: "radwo",
            github_uid: "184065",
            user_id: user.id,
            repo_host: "github"
          )

        invitees = [
          InternalApi.Guard.Invitee.new(
            email: "",
            name: "",
            provider:
              InternalApi.User.RepositoryProvider.new(
                login: "radwo",
                type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB)
              )
          )
        ]

        {:ok, u} = Guard.Store.User.Front.find(user.id)
        refute u.blocked_at == nil

        {:ok, response} =
          Request.new(inviter_id: user_id, org_id: org_id, invitees: invitees) |> make_request()

        [invitee] = response.invitees

        assert invitee.provider.login == "radwo"
        assert invitee.provider.uid == "184065"

        {:ok, u} = Guard.Store.User.Front.find(user.id)
        assert u.blocked_at == nil
      end
    end

    test "returns an error if organization doesn't exist" do
      response =
        Request.new(org_id: Ecto.UUID.generate())
        |> make_request()

      assert {:error, %GRPC.RPCError{message: "Organization not found", status: 5}} = response
    end

    test "returns an error when org maxed out number of members", %{org_id: org_id} do
      Support.Factories.Organization.insert!(id: org_id)

      with_mock FeatureProvider, feature_quota: fn :max_people_in_org, _ -> 0 end do
        {:error, %{status: 9, message: error_msg}} = Request.new(org_id: org_id) |> make_request()

        assert error_msg =~ "maximum number"
      end
    end
  end

  defp make_request(request) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")

    InternalApi.Guard.Guard.Stub.invite_collaborators(channel, request)
  end
end
