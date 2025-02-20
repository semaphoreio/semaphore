defmodule Support.Factories.FrontUser do
  alias Ecto.UUID

  def insert(options \\ []) do
    id = get_id(options[:id])
    email = get_email(options[:email])
    name = get_name(options[:name])

    %Guard.FrontRepo.User{id: id, email: email, name: name} |> Guard.FrontRepo.insert()
  end

  defp get_id(nil), do: UUID.generate()
  defp get_id(org_id), do: org_id

  defp get_email(nil),
    do: for(_ <- 1..10, into: "", do: <<Enum.random('abcdefghijk')>>) <> "@example.com"

  defp get_email(email), do: email

  defp get_name(nil), do: for(_ <- 1..10, into: "", do: <<Enum.random('abcdefghijk')>>)
  defp get_name(name), do: name
end
