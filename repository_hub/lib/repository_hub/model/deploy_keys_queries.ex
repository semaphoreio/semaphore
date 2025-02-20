defmodule RepositoryHub.Model.DeployKeyQuery do
  @moduledoc """
  SSH Keys Queries
  Operations on SSH Keys type
  """
  alias RepositoryHub.Toolkit

  alias RepositoryHub.Model.{DeployKeys, Repositories, RepositoryQuery}
  alias RepositoryHub.Repo, as: Repo

  import Ecto.Query
  import Toolkit

  @doc """
  Creates new DB record for ssh key with given params
  """
  def insert(params) do
    %DeployKeys{}
    |> DeployKeys.changeset(params)
    |> Repo.insert()
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  def update(deploy_keys, params, opts \\ []) do
    deploy_keys
    |> DeployKeys.changeset(params)
    |> Repo.update(opts)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @spec get_by_repository_id(any) :: {:error, any} | {:ok, any}
  @doc """
  Finds key by repository id
  """
  def get_by_repository_id(repository_id) do
    DeployKeys
    |> join(:inner, [ssh_keys], repository in Repositories, on: repository.project_id == ssh_keys.project_id)
    |> where([_, repository], repository.id == ^repository_id)
    |> Repo.one()
    |> case do
      nil ->
        error("Deploy key for repository not found.")

      deploy_key ->
        %{deploy_key | repository_id: repository_id}
        |> wrap()
    end
  end

  @doc """
  Finds key by its id
  """
  def get_by_id(id) do
    DeployKeys
    |> where(id: ^id)
    |> Repo.one()
    |> case do
      nil ->
        error("Deploy key not found.")

      deploy_key ->
        RepositoryQuery.get_by_project_id(deploy_key.project_id)
        |> unwrap(fn repository ->
          %{deploy_key | repository_id: repository.id}
          |> wrap()
        end)
    end
  rescue
    e -> {:error, e}
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
end
