defmodule Guard.GrpcServers.Server do
  use GRPC.Server, service: InternalApi.Guard.Guard.Service

  import Guard.Utils, only: [grpc_error!: 2]

  require Logger

  def create_member(req, _stream) do
    Watchman.benchmark("create_member", fn ->
      with {:ok, user, password} <- fetch_or_create_user(req.email, req.name, req.inviter_id),
           {:ok, message} <- assign_member_role(user.id, req.org_id) do
        InternalApi.Guard.CreateMemberResponse.new(
          password: password,
          msg: message
        )
      else
        {:error, error_msg} ->
          grpc_error!(:failed_precondition, error_msg)
      end
    end)
  end

  defp fetch_or_create_user(email, name, _requester_id) do
    case Guard.Store.RbacUser.fetch_by_email(email) do
      {:error, :not_found} ->
        password = :crypto.strong_rand_bytes(20) |> Base.url_encode64() |> binary_part(0, 20)
        user_data = %{email: email, name: name, password: password}

        case Guard.User.Actions.create(user_data) do
          {:ok, user} ->
            {:ok, user, password}

          _e ->
            {:error, "Failed to create user"}
        end

      {:ok, user} ->
        {:ok, user, ""}
    end
  end

  def reset_password(req, _stream) do
    Watchman.benchmark("reset_password", fn ->
      case Guard.Store.OIDCUser.fetch_by_user_id(req.user_id) do
        {:ok, oidc_user} ->
          {:ok, user} = Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user.oidc_user_id)

          password = :crypto.strong_rand_bytes(20) |> Base.url_encode64() |> binary_part(0, 20)

          case Guard.OIDC.User.update_oidc_user(oidc_user.oidc_user_id, user,
                 password_data: [password: password]
               ) do
            {:ok, _} ->
              InternalApi.Guard.ResetPasswordResponse.new(
                password: password,
                msg: "Password reset successfully"
              )

            {:error, error} ->
              Logger.error(
                "Failed to reset password for #{req.user_id} by #{req.requester_id} error: #{inspect(error)}"
              )

              grpc_error!(:internal, "Failed to reset password")
          end

        error ->
          Logger.error(
            "Failed to reset password for #{req.user_id} by #{req.requester_id} error: #{inspect(error)}"
          )

          grpc_error!(:failed_precondition, "User not found")
      end
    end)
  end

  def change_email(req, _stream) do
    Watchman.benchmark("change_email", fn ->
      Guard.User.Actions.change_email(req.user_id, req.email)
      |> case do
        {:ok, email} ->
          InternalApi.Guard.ChangeEmailResponse.new(
            email: email,
            msg: "Email changed successfully"
          )

        {:error, error} ->
          Logger.error(
            "Failed to change email for #{req.user_id} by #{req.requester_id} error: #{inspect(error)}"
          )

          grpc_error!(:failed_precondition, error)
      end
    end)
  end

  def refresh(_request, _stream) do
    grpc_error!(
      :unimplemented,
      "This service has been deprecated and is no longer supported. Use RBAC RefreshCollaborators instead."
    )
  end

  def invitations(%{org_id: org_id}, _) do
    Guard.Metrics.External.increment("guard_server", call: "invitations")

    Watchman.benchmark("invitations.duration", fn ->
      with :ok <- organization_exists!(org_id),
           {:ok, invitations} <- Guard.Store.Invitations.list(org_id),
           {:ok, invitations} <- Guard.Avatar.inject_avatar(invitations) do
        invitations =
          Enum.map(invitations, fn invitation ->
            InternalApi.Guard.Invitation.new(
              id: invitation.id,
              display_name: invitation.display_name,
              avatar_url: invitation.avatar_url,
              invited_at:
                Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(invitation.invited_at))
            )
          end)

        InternalApi.Guard.InvitationsResponse.new(invitations: invitations)
      end
    end)
  end

  def repository_collaborators(%{org_id: org_id, project_id: project_id}, _) do
    Guard.Metrics.External.increment("guard_server", call: "repository_collaborators")

    Watchman.benchmark("collaborators.duration", fn ->
      with :ok <- organization_exists!(org_id),
           {:ok, collaborators} <- Guard.Store.Invitations.collaborators(org_id, project_id),
           {:ok, collaborators} <- Guard.Avatar.inject_avatar(collaborators) do
        collaborators =
          Enum.map(collaborators, fn collaborator ->
            InternalApi.Guard.RepositoryCollaborator.new(
              display_name: collaborator.display_name,
              avatar_url: collaborator.avatar_url,
              repository_provider:
                InternalApi.User.RepositoryProvider.new(
                  type: map_repository_provider_type(collaborator.provider),
                  login: collaborator.login,
                  uid: collaborator.uid
                )
            )
          end)

        InternalApi.Guard.RepositoryCollaboratorsResponse.new(collaborators: collaborators)
      end
    end)
  end

  def invite_collaborators(%{inviter_id: inviter_id, org_id: org_id, invitees: invitees}, _) do
    Guard.Metrics.External.increment("guard_server", call: "invite_collaborators")

    Watchman.benchmark("invite_collaborators.duration", fn ->
      with :ok <- organization_exists!(org_id),
           {:ok, _} <- Guard.Store.Organization.can_add_new_member?(org_id),
           invitees <- Enum.map(invitees, fn invitee -> Util.Proto.to_map!(invitee) end),
           {:ok, invitees} <- Guard.Invitees.inject_provider_uid(invitees, inviter_id),
           {:ok, members} <- Guard.Store.Invitations.create(invitees, org_id),
           user_ids <- Guard.Store.Members.extract_user_id(members) do
        Guard.Events.UserJoinedOrganization.publish(members, org_id)
        assign_member_roles(user_ids, org_id)
        unblock_users(user_ids)

        invitees =
          members
          |> Enum.map(fn member ->
            InternalApi.Guard.Invitee.new(
              email: member.invite_email || "",
              provider:
                InternalApi.User.RepositoryProvider.new(
                  type: map_repository_provider_type(member.repo_host),
                  login: member.github_username,
                  uid: member.github_uid
                )
            )
          end)

        InternalApi.Guard.InviteCollaboratorsResponse.new(invitees: invitees)
      else
        {:error, error_msg} ->
          raise(GRPC.RPCError,
            status: GRPC.Status.failed_precondition(),
            message: error_msg
          )

        _ ->
          raise(GRPC.RPCError, status: GRPC.Status.failed_precondition())
      end
    end)
  end

  defp organization_exists!(org_id) do
    Guard.Store.Organization.exists?(org_id)
    |> case do
      true ->
        :ok

      false ->
        raise GRPC.RPCError, status: GRPC.Status.not_found(), message: "Organization not found"
    end
  end

  defp assign_member_roles(user_ids, org_id) do
    GenRetry.retry(
      fn ->
        Enum.each(user_ids, fn user_id ->
          assign_member_role(user_id, org_id)
        end)
      end,
      retries: 10,
      delay: 3000,
      jitter: 0.2
    )
  end

  # This function is made to work only with invite collaborators! (It will not assign)
  # a member role if the user already has a role with that organization
  defp assign_member_role(user_id, org_id) do
    if Guard.Api.Rbac.user_part_of_org?(user_id, org_id) do
      {:ok, "User is already part of the organization"}
    else
      Guard.Api.Rbac.assign_org_role_by_name(org_id, user_id, "Member")
      Guard.Events.Authorization.publish("role_assigned", user_id, org_id)
      {:ok, "User added to the organization"}
    end
  end

  defp unblock_users(user_ids),
    do: Enum.each(user_ids, fn user_id -> unblock_user(user_id) end)

  defp unblock_user(user_id) do
    Guard.Store.User.Front.unblock(user_id)
  end

  defp map_repository_provider_type("github"),
    do: InternalApi.User.RepositoryProvider.Type.value(:GITHUB)

  defp map_repository_provider_type("bitbucket"),
    do: InternalApi.User.RepositoryProvider.Type.value(:BITBUCKET)

  defp map_repository_provider_type("gitlab"),
    do: InternalApi.User.RepositoryProvider.Type.value(:GITLAB)
end
