defmodule RepositoryHub.Model.GithubAppQuery do
  @moduledoc """
  Queries used to fetch GithubApp installation data
  """

  import Ecto.Query

  alias RepositoryHub.Model.GithubAppCollaborators
  alias RepositoryHub.PagedResult
  alias RepositoryHub.Repo
  alias RepositoryHub.Model
  import Ecto.Query

  @doc """
  """
  @spec list_repositories([non_neg_integer()], [Model.Repositories.t()]) :: PagedResult.t()
  def list_repositories(github_uids, _pagination \\ []) do
    from(GithubAppCollaborators)
    |> where([c], c.c_id in ^github_uids)
    |> Repo.all()
  end
end
