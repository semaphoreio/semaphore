defmodule Auth.IdProvider do
  require Logger

  def id_provider_allowed?(user, org) do
    if !allowed_id_providers_exist?(org) or
         provider_in_allowed_list?(org.allowed_id_providers, user.id_provider) do
      true
    else
      Logger.info(
        "[Id Provider] User #{inspect(user)} used wrong id_provider to access #{inspect(org)}"
      )

      false
    end
  end

  # Check if org has a list of allowed id providers set up
  defp allowed_id_providers_exist?(org) do
    org.allowed_id_providers != []
  end

  defp provider_in_allowed_list?(allowed_id_providers, id_provider) do
    id_provider_string =
      Atom.to_string(id_provider)
      |> String.replace("ID_PROVIDER_", "")
      |> String.downcase()

    allowed_id_providers
    |> Enum.map(&String.downcase/1)
    |> Enum.member?(id_provider_string)
  end
end
