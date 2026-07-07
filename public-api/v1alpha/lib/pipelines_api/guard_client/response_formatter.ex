defmodule PipelinesAPI.GuardClient.ResponseFormatter do
  @moduledoc false

  @provider_names %{0 => "github", 1 => "bitbucket", 2 => "gitlab"}

  def process_invite_collaborators_response({:ok, response}) do
    case response.invitees do
      [invitee | _] -> {:ok, serialize(invitee)}
      _ -> {:ok, %{}}
    end
  end

  def process_invite_collaborators_response(error), do: error

  defp serialize(invitee) do
    provider = invitee.provider || %{}

    %{
      email: Map.get(invitee, :email, ""),
      name: Map.get(invitee, :name, ""),
      provider: provider_name(Map.get(provider, :type)),
      handle: Map.get(provider, :login, ""),
      uid: Map.get(provider, :uid, "")
    }
  end

  defp provider_name(type), do: Map.get(@provider_names, type, "")
end
