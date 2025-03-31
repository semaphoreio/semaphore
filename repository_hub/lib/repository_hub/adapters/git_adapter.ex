defmodule RepositoryHub.GitAdapter do
  @moduledoc """

  """
  alias RepositoryHub.{
    UniversalAdapter,
    GitAdapter
  }

  @type t :: %RepositoryHub.GitAdapter{}

  defstruct [:integration_type, :name, :short_name]

  @doc """
  Creates a new GitAdapter

  # Examples

    iex> RepositoryHub.GitAdapter.new("git")
    %RepositoryHub.GitAdapter{integration_type: "git", name: "Git", short_name: "git"}

    iex> RepositoryHub.GitAdapter.new("GIT")
    %RepositoryHub.GitAdapter{integration_type: "git", name: "Git", short_name: "git"}
  """
  @spec new(integration_type :: String.t()) :: GitAdapter.t()
  def new(integration_type) do
    %GitAdapter{
      integration_type: String.downcase(integration_type),
      name: "Git",
      short_name: "git"
    }
  end

  def integration_types, do: ["git"]

  def context(_adapter, repository_id, stream \\ nil) do
    UniversalAdapter.context(repository_id, stream)
  end

  def multi(_adapter, repository_id, stream \\ nil) do
    alias Ecto.Multi

    with {:ok, context} <- UniversalAdapter.context(repository_id, stream) do
      Enum.reduce(context, Multi.new(), fn {key, value}, multi ->
        multi
        |> Multi.put(key, value)
      end)
    end
  end
end
