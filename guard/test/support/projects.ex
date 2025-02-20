defmodule Support.Projects do
  alias Guard.{Repo, FrontRepo}

  def insert(params) do
    default = [
      project_id: Ecto.UUID.generate(),
      repo_name: "renderedtext/guard",
      org_id: Ecto.UUID.generate(),
      provider: "github",
      repository_id: Ecto.UUID.generate()
    ]

    params = default |> Keyword.merge(params)
    project = Kernel.struct(Repo.Project, params)

    front_params = [
      id: params[:project_id],
      organization_id: params[:org_id],
      state: params[:state]
    ]

    front_project = Kernel.struct(FrontRepo.Project, front_params)

    FrontRepo.insert(front_project)
    Repo.insert(project)
  end
end
