defmodule Support.Projects do
  alias Rbac.Repo

  def insert(params) do
    default = [
      project_id: Ecto.UUID.generate(),
      repo_name: "renderedtext/rbac",
      org_id: Ecto.UUID.generate(),
      provider: "github",
      repository_id: Ecto.UUID.generate()
    ]

    params = default |> Keyword.merge(params)
    project = Kernel.struct(Repo.Project, params)

    Repo.insert(project)
  end
end
