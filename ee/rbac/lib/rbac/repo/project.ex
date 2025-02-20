defmodule Rbac.Repo.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "projects" do
    field(:project_id, :binary_id)
    field(:repo_name, :string)
    field(:repository_id, :string)
    field(:provider, :string)
    field(:org_id, :binary_id)

    timestamps(type: :naive_datetime_usec)
  end

  def changeset(project, params \\ %{}) do
    project
    |> cast(params, [:project_id, :repo_name, :provider, :org_id, :repository_id])
    |> validate_required([:project_id, :repo_name, :provider, :org_id])
    |> unique_constraint(:project_id)
  end
end
