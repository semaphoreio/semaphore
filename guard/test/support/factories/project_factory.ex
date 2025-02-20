defmodule Support.Factories.Project do
  alias Guard.Repo.Project

  def insert(options \\ []) do
    %Project{
      project_id: get_id(options[:id]),
      repo_name: get_name(options[:repo_name]),
      repository_id: get_id(options[:repository_id]),
      provider: get_provider(options[:provider]),
      org_id: get_id(options[:org_id])
    }
    |> Guard.Repo.insert()
  end

  defp get_name(nil), do: for(_ <- 1..10, into: "", do: <<Enum.random('abcdefghijk')>>)
  defp get_name(name), do: name

  defp get_id(nil), do: Ecto.UUID.generate()
  defp get_id(id), do: id

  defp get_provider(nil), do: "github"
  defp get_provider(provider), do: provider
end
