defmodule RepositoryHub.Model.RepositoryQuery do
  @moduledoc """
  Repositories Queries
  Operations on Repositories type
  """

  import Ecto.Query

  alias RepositoryHub.Model.Repositories
  alias RepositoryHub.Repo, as: Repo
  import RepositoryHub.Toolkit

  @doc """
  Creates new DB record for repository with given params
  """
  def insert(params, opts \\ []) do
    %Repositories{}
    |> Repositories.changeset(params)
    |> Repo.insert(opts)
    |> unwrap_error(fn changeset ->
      changeset
      |> consolidate_changeset_errors()
      |> error
    end)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  """
  def update(repository, params, opts \\ []) do
    repository
    |> Repositories.changeset(params)
    |> Repo.update(opts)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  """
  def delete(id, opts \\ []) do
    get_by_id(id)
    |> unwrap(fn repository ->
      repository
      |> Repo.delete(opts)
    end)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  Finds repository by its id
  """
  @spec get_by_id(String.t()) :: {:ok, Repositories.t()} | {:error, String.t()}
  def get_by_id(id) do
    Repositories
    |> where(id: ^id)
    |> Repo.one()
    |> case do
      nil ->
        error("Repository not found.")

      repository ->
        repository
    end
    |> wrap()
  rescue
    e -> {:error, e}
  end

  @doc """
  Finds repository by its project id
  """
  def get_by_project_id(project_id) do
    Repositories
    |> where(project_id: ^project_id)
    |> Repo.one()
    |> case do
      nil ->
        error("Repository with project id: '#{project_id}' not found.")

      repository ->
        repository
    end
    |> wrap()
  rescue
    e -> {:error, e}
  end

  @doc """
  Locks next connected GitHub repository without remote_id.
  Must be called within a transaction.
  """
  def lock_next_github_without_remote_id do
    from(repository in Repositories,
      where: repository.integration_type in ["github_app", "github_oauth_token"],
      where: repository.connected == true,
      where: is_nil(repository.remote_id) or repository.remote_id == "",
      order_by: [asc: repository.inserted_at],
      limit: 1,
      lock: "FOR UPDATE SKIP LOCKED"
    )
    |> Repo.one()
  end

  @doc """
  List all repositories
  """
  def list_by_project(project_id) do
    filter(%{project_id: project_id})
  end

  def filter(filters) do
    from(Repositories)
    |> filter_by(filters)
    |> Repo.all()
  end

  defp filter_by(query, filters) do
    filters
    |> Enum.reduce(query, fn
      {:project_id, value}, query when is_list(value) ->
        query
        |> or_where([repository], repository.project_id in ^value)

      {:project_id, value}, query ->
        query
        |> or_where([repository], repository.project_id == ^value)

      {:id, value}, query when is_list(value) ->
        query
        |> or_where([repository], repository.id in ^value)

      {:id, value}, query ->
        query
        |> or_where([repository], repository.id == ^value)

      _, query ->
        query
    end)
  end
end
