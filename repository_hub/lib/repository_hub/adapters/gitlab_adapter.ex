defmodule RepositoryHub.GitlabAdapter do
  @moduledoc """

  """
  alias RepositoryHub.{
    UniversalAdapter,
    UserClient,
    Toolkit,
    GitlabAdapter
  }

  import Toolkit

  @type t :: %RepositoryHub.GitlabAdapter{}

  defstruct [:integration_type, :name, :short_name]

  @doc """
  Creates a new GitlabAdapter

  # Examples

    iex> RepositoryHub.GitlabAdapter.new("gitlab")
    %RepositoryHub.GitlabAdapter{integration_type: "gitlab", name: "Gitlab", short_name: "gitlab"}

    iex> RepositoryHub.GitlabAdapter.new("GITLAB")
    %RepositoryHub.GitlabAdapter{integration_type: "gitlab", name: "Gitlab", short_name: "gitlab"}
  """
  @spec new(integration_type :: String.t()) :: GitlabAdapter.t()
  def new(integration_type) do
    %GitlabAdapter{
      integration_type: String.downcase(integration_type),
      name: "Gitlab",
      short_name: "gitlab"
    }
  end

  def integration_types, do: ["gitlab"]

  def multi(_adapter, repository_id, stream \\ nil) do
    alias Ecto.Multi

    with {:ok, context} <- UniversalAdapter.context(repository_id, stream) do
      Enum.reduce(context, Multi.new(), fn {key, value}, multi ->
        multi
        |> Multi.put(key, value)
      end)
      |> Multi.run(:gitlab_token, fn _repo, context ->
        fetch_token(context.project.metadata.owner_id)
      end)
    end
  end

  def fetch_token(user_id) do
    [integration_type] = integration_types()

    integration_type
    |> UserClient.get_repository_token(user_id)
  end

  def context(_adapter, repository_id, stream \\ nil) do
    with {:ok, context} <- UniversalAdapter.context(repository_id, stream),
         {:ok, gitlab_token} <- GitlabAdapter.fetch_token(context.project.metadata.owner_id) do
      context
      |> Map.put(:gitlab_token, gitlab_token)
      |> wrap()
    end
  end
end
