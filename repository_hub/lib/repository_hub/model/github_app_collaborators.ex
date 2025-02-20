defmodule RepositoryHub.Model.GithubAppCollaborators do
  @moduledoc """
  GithubApp collaborators
  """

  use RepositoryHub.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "github_app_collaborators" do
    field(:installation_id, :integer)
    field(:c_id, :integer)
    field(:c_name, :string)
    field(:r_name, :string)
  end
end
