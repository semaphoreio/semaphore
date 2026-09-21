defmodule PipelinesAPI.GuardClient.RequestFormatter do
  @moduledoc false
  alias Plug.Conn
  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.Guard.{InviteCollaboratorsRequest, Invitee}
  alias InternalApi.User.RepositoryProvider

  @providers %{
    "github" => RepositoryProvider.Type.value(:GITHUB),
    "bitbucket" => RepositoryProvider.Type.value(:BITBUCKET),
    "gitlab" => RepositoryProvider.Type.value(:GITLAB)
  }

  def form_invite_collaborators_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    inviter_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")

    provider = params |> Map.get("provider", "") |> to_string() |> String.downcase()
    handle = Map.get(params, "handle", "")
    uid = Map.get(params, "uid", "")
    name = Map.get(params, "name", "")
    email = Map.get(params, "email", "")

    with {:ok, provider_type} <- provider_type(provider),
         :ok <- validate_handle(handle),
         :ok <- validate_bitbucket_uid(provider, uid) do
      InviteCollaboratorsRequest.new(
        inviter_id: inviter_id,
        org_id: org_id,
        invitees: [
          Invitee.new(
            email: email,
            name: name,
            provider:
              RepositoryProvider.new(
                type: provider_type,
                login: handle,
                uid: uid
              )
          )
        ]
      )
      |> ToTuple.ok()
    end
  catch
    error -> error
  end

  def form_invite_collaborators_request(_, _), do: ToTuple.internal_error("Internal error")

  defp provider_type(provider) do
    case Map.fetch(@providers, provider) do
      {:ok, type} -> {:ok, type}
      :error -> ToTuple.user_error("provider must be one of: github, bitbucket, gitlab")
    end
  end

  defp validate_handle(""), do: ToTuple.user_error("handle must be provided")
  defp validate_handle(handle) when is_binary(handle), do: :ok
  defp validate_handle(_), do: ToTuple.user_error("handle must be a string")

  defp validate_bitbucket_uid("bitbucket", ""),
    do: ToTuple.user_error("uid must be provided for bitbucket invitees")

  defp validate_bitbucket_uid(_provider, _uid), do: :ok
end
