defmodule Support.Factories.Group do
  alias Ecto.UUID

  def insert(options \\ []) do
    id = get_id(options[:group_id])

    %Rbac.Repo.Subject{id: id, name: get_name(options[:name]), type: "group"}
    |> Rbac.Repo.insert()

    %Rbac.Repo.Group{
      id: id,
      org_id: get_id(options[:org_id]),
      creator_id: get_id(options[:creator_id]),
      description: get_name(options[:description])
    }
    |> Rbac.Repo.insert()
  end

  defp get_id(nil), do: UUID.generate()
  defp get_id(org_id), do: org_id

  defp get_name(nil), do: for(_ <- 1..10, into: "", do: <<Enum.random(~c"abcdefghijk")>>)
  defp get_name(name), do: name
end
