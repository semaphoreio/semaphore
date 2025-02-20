defmodule RepositoryHub.GithubAppFactory do
  import RepositoryHub.Toolkit
  alias RepositoryHub.{Model, Repo}
  alias Model.{GithubAppCollaborators, GithubAppInstallations}

  def create_installation(params \\ []) do
    installation_params(params)
    |> then(&struct(GithubAppInstallations, &1))
    |> Repo.insert()
  end

  def create_collaborator(params \\ []) do
    collaborator_params(params)
    |> then(&struct(GithubAppCollaborators, &1))
    |> Repo.insert()
  end

  def installation_params(params) do
    params
    |> with_defaults([])
    |> Enum.into(%{})
  end

  def collaborator_params(params) do
    params
    |> with_defaults(
      installation_id: 1,
      c_id: 1,
      c_name: "robot",
      r_name: "rebot/repository"
    )
  end
end
