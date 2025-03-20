defmodule Support.Factories.SamlJitUser do
  alias Rbac.Repo.SamlJitUser
  alias Ecto.UUID

  @doc """
    Expected arg options:
    - org_id (organization which owns the mapper)
    - sso_url (url for okta single sign on)

    All of these parameters are optional. If role id are not given, new roles will be created and used.
    If org_id is not given, new one will be generated
  """
  def insert(options \\ []) do
    %SamlJitUser{
      org_id: get_id(options[:org_id]),
      integration_id: get_integration_id(options[:integration_id]),
      attributes: get_attributes(options[:attributes]),
      state: get_state(options[:state]),
      email: get_email(options[:email])
    }
    |> Rbac.Repo.insert(on_conflict: :replace_all, conflict_target: :id)
  end

  defp get_id(nil), do: UUID.generate()
  defp get_id(id), do: id

  defp get_email(nil), do: "#{get_string(nil)}@#{get_string(nil)}.com"
  defp get_email(string), do: string

  defp get_string(nil), do: for(_ <- 1..10, into: "", do: <<Enum.random(~c"abcdefghijk")>>)
  defp get_string(string), do: string

  defp get_state(nil), do: :pending
  defp get_state(state), do: state

  defp get_integration_id(nil),
    do: Support.Factories.OktaIntegration.insert() |> elem(1) |> Map.get(:id)

  defp get_integration_id(id), do: id

  defp get_attributes(nil), do: %{}
  defp get_attributes(attributes), do: attributes
end
