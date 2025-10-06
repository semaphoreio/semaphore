defmodule Rbac.Repo.Subject do
  use Rbac.Repo.Schema
  import Ecto.Query

  schema "subjects" do
    has_many(:role_bindings, Rbac.Repo.SubjectRoleBinding)
    field(:type, :string)
    field(:name, :string)

    timestamps()
  end

  @spec find_by_id(String.t()) :: %__MODULE__{}
  def find_by_id(id) do
    __MODULE__ |> where([s], s.id == ^id) |> Rbac.Repo.one()
  end

  @spec find_by_ids_and_org([String.t()], String.t()) :: [%__MODULE__{}]
  def find_by_ids_and_org(subject_ids, org_id) do
    __MODULE__
    |> join(:inner, [s], srb in assoc(s, :role_bindings))
    |> where([s, srb], s.id in ^subject_ids and srb.org_id == ^org_id)
    |> distinct([s], s.id)
    |> Rbac.Repo.all()
  end

  def changeset(subject, params \\ %{}) do
    subject
    |> cast(params, [:id, :name, :type])
    |> validate_required([:id, :name, :type])
    |> unique_constraint(:id, name: :subjects_pkey)
  end
end
