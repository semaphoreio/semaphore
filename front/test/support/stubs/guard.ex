defmodule Support.Stubs.Guard do
  def init do
    __MODULE__.Grpc.init()
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(GuardMock, :change_email, &__MODULE__.change_email/2)
      GrpcMock.stub(GuardMock, :reset_password, &__MODULE__.reset_password/2)
      GrpcMock.stub(GuardMock, :create_member, &__MODULE__.create_member/2)
      GrpcMock.stub(GuardMock, :refresh, &__MODULE__.refresh/2)
      GrpcMock.stub(GuardMock, :repository_collaborators, &__MODULE__.repository_collaborators/2)
      GrpcMock.stub(GuardMock, :invitations, &__MODULE__.invitations/2)
      GrpcMock.stub(GuardMock, :invite_collaborators, &__MODULE__.invite_collaborators/2)
    end

    def reset_password(%{requester_id: _, user_id: "fail"}, _) do
      raise GRPC.RPCError,
        status: GRPC.Status.failed_precondition(),
        message: "Failed to reset password"
    end

    def reset_password(%{requester_id: _, user_id: _}, _) do
      InternalApi.Guard.ResetPasswordResponse.new(
        password: :crypto.strong_rand_bytes(20) |> Base.url_encode64() |> binary_part(0, 20),
        msg: "Password reset"
      )
    end

    def create_member(%{org_id: _, inviter_id: _, email: _, name: "fail"}, _) do
      raise GRPC.RPCError,
        status: GRPC.Status.failed_precondition(),
        message: "Failed to create user"
    end

    def create_member(%{org_id: _, inviter_id: _, email: _, name: "existing"}, _) do
      InternalApi.Guard.CreateMemberResponse.new(
        password: "",
        msg: "User is already a member"
      )
    end

    def create_member(%{org_id: _, inviter_id: _, email: _, name: _}, _) do
      InternalApi.Guard.CreateMemberResponse.new(
        password: :crypto.strong_rand_bytes(20) |> Base.url_encode64() |> binary_part(0, 20),
        msg: "User added to the organization"
      )
    end

    def invite_collaborators(%{inviter_id: _, org_id: _, invitees: invitees}, _) do
      InternalApi.Guard.InviteCollaboratorsResponse.new(invitees: invitees)
    end

    def invitations(_, _) do
      invitations = [
        InternalApi.Guard.Invitation.new(
          id: Support.Stubs.UUID.gen(),
          invited_at: Support.Stubs.Time.now(),
          display_name: "Frank",
          avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4"
        )
      ]

      InternalApi.Guard.InvitationsResponse.new(invitations: invitations)
    end

    def repository_collaborators(_, _) do
      collaborators = [
        InternalApi.Guard.RepositoryCollaborator.new(
          display_name: "radwo",
          avatar_url: "https://avatars.githubusercontent.com/u/0?v=4",
          repository_provider:
            InternalApi.User.RepositoryProvider.new(
              login: "radwo",
              uid: "184065",
              type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB)
            )
        ),
        InternalApi.Guard.RepositoryCollaborator.new(
          display_name: "radwo",
          avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
          repository_provider:
            InternalApi.User.RepositoryProvider.new(
              login: "radwo",
              uid: "{babc48bc-fc2c-46f8-aae0-34c5ec255ffb}",
              type: InternalApi.User.RepositoryProvider.Type.value(:BITBUCKET)
            )
        )
      ]

      InternalApi.Guard.RepositoryCollaboratorsResponse.new(collaborators: collaborators)
    end

    def refresh(_, _) do
      InternalApi.Guard.RefreshResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
      )
    end

    def change_email(req, _) do
      req.email
      |> case do
        "fail@example.com" ->
          raise GRPC.RPCError,
            status: GRPC.Status.failed_precondition(),
            message: "Failed to change email"

        _ ->
          InternalApi.Guard.ChangeEmailResponse.new(
            email: req.email,
            msg: "Updated email"
          )
      end
    end
  end
end
