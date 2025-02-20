defmodule Support.Factories.FrontUser do
  alias Ecto.UUID

  def insert(options \\ []) do
    id = get_id(options[:id])
    email = get_email(options[:email])

    %Rbac.FrontRepo.User{id: id, email: email} |> Rbac.FrontRepo.insert()
  end

  defp get_id(nil), do: UUID.generate()
  defp get_id(org_id), do: org_id

  defp get_email(nil),
    do: for(_ <- 1..10, into: "", do: <<Enum.random(~c"abcdefghijk")>>) <> "@example.com"

  defp get_email(email), do: email
end
