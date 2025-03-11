defmodule Rbac.Repo.SubjectRoleBinding do
  use Rbac.Repo.Schema
  alias Rbac.Repo.{RbacRole, Subject}
  import Ecto.Query, only: [where: 3]

  @binding_sources ~w(github bitbucket gitlab manually_assigned okta inherited_from_org_role saml_jit)a

  schema "subject_role_bindings" do
    belongs_to(:role, RbacRole)
    field(:org_id, :binary_id)
    field(:project_id, :binary_id)
    belongs_to(:subject, Subject)
    field(:binding_source, Ecto.Enum, values: @binding_sources)

    timestamps()
  end

  def create(org_id, project_id, subject_id, source, role_id) when source in @binding_sources do
    %__MODULE__{
      subject_id: subject_id,
      org_id: org_id,
      project_id: project_id,
      role_id: role_id,
      binding_source: source
    }
    |> Rbac.Repo.insert(
      on_conflict: :replace_all,
      conflict_target: {
        :unsafe_fragment,
        if project_id == nil do
          ~s<("subject_id", "org_id", "binding_source") WHERE project_id IS NULL>
        else
          ~s<("subject_id", "org_id", "project_id", "binding_source") WHERE project_id IS NOT NULL>
        end
      }
    )
  end

  @doc """
    These 4 args uniquely define each subject_role_bindings
  """
  def delete(org_id, project_id, subject_id, source) when source in @binding_sources do
    __MODULE__
    |> where(
      [srb],
      srb.org_id == ^org_id and srb.project_id == ^project_id and srb.subject_id == ^subject_id and
        srb.binding_source == ^source
    )
    |> Rbac.Repo.delete_all()
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
