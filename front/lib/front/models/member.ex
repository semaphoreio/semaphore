defmodule Front.Models.Member do
  require Logger

  def create(email, name, org_id, requester_id) do
    Watchman.benchmark("create_member", fn ->
      req =
        InternalApi.Guard.CreateMemberRequest.new(
          email: email,
          name: name,
          org_id: org_id,
          inviter_id: requester_id
        )

      {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:front, :guard_grpc_endpoint))

      case InternalApi.Guard.Guard.Stub.create_member(channel, req) do
        {:ok, res} ->
          {:ok, res}

        error ->
          Logger.error("Create Member Error #{inspect(req)} error: #{inspect(error)}")
          {:error, "Failed to create member"}
      end
    end)
  end

  def reset_password(requester_id, user_id) do
    Watchman.benchmark("reset_password", fn ->
      req =
        InternalApi.Guard.ResetPasswordRequest.new(
          requester_id: requester_id,
          user_id: user_id
        )

      {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:front, :guard_grpc_endpoint))

      case InternalApi.Guard.Guard.Stub.reset_password(channel, req) do
        {:ok, res} ->
          {:ok, res}

        error ->
          Logger.error("Reset Password Error #{inspect(req)} error: #{inspect(error)}")
          {:error, "Failed to reset password"}
      end
    end)
  end

  def change_email(requester_id, user_id, email) do
    Watchman.benchmark("change_email", fn ->
      req =
        InternalApi.Guard.ChangeEmailRequest.new(
          requester_id: requester_id,
          user_id: user_id,
          email: email
        )

      {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:front, :guard_grpc_endpoint))

      case InternalApi.Guard.Guard.Stub.change_email(channel, req) do
        {:ok, res} ->
          {:ok, res}

        {:error, %GRPC.RPCError{message: msg} = error} ->
          Logger.error("Change email Error #{inspect(req)} error: #{inspect(error)}")
          {:error, msg}
      end
    end)
  end

  def invitations(org_id) do
    Watchman.benchmark("fetch_org_invitations.duration", fn ->
      req = InternalApi.Guard.InvitationsRequest.new(org_id: org_id)

      {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:front, :guard_grpc_endpoint))

      Logger.info("Invitations Request: #{inspect(req)}")

      case InternalApi.Guard.Guard.Stub.invitations(channel, req, timeout: 30_000) do
        {:ok, res} ->
          Logger.info("Invitations Response: #{inspect(res)}")

          {:ok, res.invitations}

        error ->
          Logger.error("Invitations Response Error: #{inspect(error)}")

          {:error, []}
      end
    end)
  end

  def repository_collaborators(org_id, project_id \\ "") do
    Watchman.benchmark("fetch_org_collaborators.duration", fn ->
      req =
        InternalApi.Guard.RepositoryCollaboratorsRequest.new(
          org_id: org_id,
          project_id: project_id
        )

      {:ok, channel} = GRPC.Stub.connect(Application.fetch_env!(:front, :guard_grpc_endpoint))

      Logger.info("Collaborators Request: #{inspect(req)}")

      case InternalApi.Guard.Guard.Stub.repository_collaborators(channel, req, timeout: 30_000) do
        {:ok, res} ->
          Logger.info("Collaborators Response: #{inspect(res)}")

          {:ok, res.collaborators}

        error ->
          Logger.error("Collaborators Response Error: #{inspect(error)}")

          {:error, []}
      end
    end)
  end

  def invite(invitees, org_id, inviter_id) do
    Watchman.benchmark("bulk_create_member.duration", fn ->
      req =
        InternalApi.Guard.InviteCollaboratorsRequest.new(
          inviter_id: inviter_id,
          org_id: org_id,
          invitees:
            invitees
            |> Enum.map(fn m ->
              InternalApi.Guard.Invitee.new(
                email: m["invite_email"],
                name: "",
                provider:
                  InternalApi.User.RepositoryProvider.new(
                    login: m["username"],
                    uid: m["uid"],
                    type: map_repository_provider_type(m["provider"])
                  )
              )
            end)
        )

      {:ok, channel} = GRPC.Stub.connect(guard_api_endpoint())

      case InternalApi.Guard.Guard.Stub.invite_collaborators(channel, req) do
        {:ok, res} ->
          {:ok, res.invitees}

        {:error, %{message: err_msg}} ->
          {:error, err_msg}
      end
    end)
  end

  alias InternalApi.User.RepositoryProvider.Type
  defp map_repository_provider_type("github"), do: Type.value(:GITHUB)
  defp map_repository_provider_type("bitbucket"), do: Type.value(:BITBUCKET)
  defp map_repository_provider_type("gitlab"), do: Type.value(:GITLAB)

  def destroy(org_id, options \\ []) do
    Watchman.benchmark("destory_member.duration", fn ->
      defaults = [org_id: org_id, user_id: "", membership_id: ""]

      req =
        Keyword.merge(defaults, options)
        |> Enum.into(%{})
        |> InternalApi.Organization.DeleteMemberRequest.new()

      {:ok, channel} = GRPC.Stub.connect(organization_api_endpoint())

      {:ok, res} =
        InternalApi.Organization.OrganizationService.Stub.delete_member(
          channel,
          req
        )

      case {res.status.code, res.status.message} do
        {0, _} ->
          {:ok, true}

        {status_code, message} ->
          {:error, message}

          Logger.error(
            "Member deletion for Organization '#{org_id}' failed with response: status => #{status_code}, message => #{message}"
          )

          {:error, message}
      end
    end)
  end

  defp organization_api_endpoint do
    Application.fetch_env!(:front, :organization_api_grpc_endpoint)
  end

  defp guard_api_endpoint do
    Application.fetch_env!(:front, :guard_grpc_endpoint)
  end
end
