defmodule Support.Factories.OktaUser do
  alias Rbac.Repo.OktaUser
  alias Ecto.UUID

  @doc """
    Expected arg options:
    - org_id (organization which owns the mapper)
    - sso_url (url for okta single sign on)

    All of these parameters are optional. If role id are not given, new roles will be created and used.
    If org_id is not given, new one will be generated
  """
  def insert(options \\ []) do
    %OktaUser{
      org_id: get_id(options[:org_id]),
      integration_id: get_id(options[:integration_id]),
      payload: get_payload(options[:payload]),
      state: get_state(options[:state]),
      user_id: get_id(options[:user_id]),
      email: get_string(options[:email])
    }
    |> Rbac.Repo.insert(on_conflict: :replace_all, conflict_target: :id)
  end

  defp get_id(nil), do: UUID.generate()
  defp get_id(id), do: id

  defp get_string(nil), do: for(_ <- 1..10, into: "", do: <<Enum.random(~c"abcdefghijk")>>)
  defp get_string(string), do: string

  defp get_state(nil), do: :pending
  defp get_state(state), do: state

  defp get_payload(nil), do: %{}
  defp get_payload(payload), do: payload
end
