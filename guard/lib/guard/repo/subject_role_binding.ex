defmodule Guard.Repo.SubjectRoleBinding do
  use Guard.Repo.Schema
  alias Guard.Repo.Subject

  @binding_sources ~w(github bitbucket gitlab manually_assigned okta inherited_from_org_role)a

  schema "subject_role_bindings" do
    field(:role_id, :binary_id)
    field(:org_id, :binary_id)
    field(:project_id, :binary_id)
    belongs_to(:subject, Subject)
    field(:binding_source, Ecto.Enum, values: @binding_sources)

    timestamps()
  end

  def changeset(subject_role_binding, params \\ %{}) do
    subject_role_binding
    |> cast(params, [:id, :role_id, :org_id, :project_id, :subject_id, :binding_source])
    |> unique_constraint([:subject_id, :org_id, :role_id, :binding_source])
    |> validate_required([:role_id, :subject_id, :binding_source])
    |> foreign_key_constraint(:subject_id)
    |> foreign_key_constraint(:role_id)
  end
end
