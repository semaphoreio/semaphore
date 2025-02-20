defmodule Support.Factories.RbacUser do
  alias Guard.Repo.{Subject, RbacUser}

  def insert(
        user_id \\ Ecto.UUID.generate(),
        name \\ random_string(),
        email \\ "#{random_string()}@example.com"
      ) do
    {:ok, _} = %Subject{id: user_id, name: name, type: "user"} |> Guard.Repo.insert()
    %RbacUser{id: user_id, name: name, email: email} |> Guard.Repo.insert()
  end

  defp random_string, do: for(_ <- 1..10, into: "", do: <<Enum.random('abcdefghijk')>>)
end
