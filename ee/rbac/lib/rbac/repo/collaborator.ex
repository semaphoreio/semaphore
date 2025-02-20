defmodule Rbac.Repo.Collaborator do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "collaborators" do
    field(:project_id, :binary_id)
    field(:github_username, :string)
    field(:github_uid, :string)
    field(:github_email, :string)
    field(:admin, :boolean)
    field(:push, :boolean)
    field(:pull, :boolean)

    timestamps(type: :naive_datetime_usec)
  end

  def changeset(collaborator, params \\ %{}) do
    collaborator
    |> cast(params, [
      :project_id,
      :github_username,
      :github_uid,
      :github_email,
      :admin,
      :push,
      :pull
    ])
    |> validate_required([:project_id, :github_uid, :github_username])
    |> unique_constraint(:github_uid, name: :unique_githubber_in_project)
  end
end
