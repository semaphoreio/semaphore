defmodule Guard.Repo.Subject do
  use Guard.Repo.Schema
  import Ecto.Query, only: [where: 3]

  schema "subjects" do
    has_many(:role_bindings, Guard.Repo.SubjectRoleBinding)
    field(:type, :string)
    field(:name, :string)

    timestamps()
  end

  @spec find_by_id(String.t()) :: %__MODULE__{}
  def find_by_id(id) do
    __MODULE__ |> where([s], s.id == ^id) |> Guard.Repo.one()
  end

  def changeset(subject, params \\ %{}) do
    subject
    |> cast(params, [:id, :name, :type])
    |> validate_required([:id, :name, :type])
    |> unique_constraint(:id, name: :subjects_pkey)
  end
end
