defmodule RepositoryHub.Model.GithubAppInstallations do
  @moduledoc """
  GithubApp installations
  """

  use RepositoryHub.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "github_app_installations" do
    field(:installation_id, :integer)

    field(:repositories, :map)
    timestamps(inserted_at_source: :created_at)
  end
end
