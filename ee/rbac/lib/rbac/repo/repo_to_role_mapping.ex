defmodule Rbac.Repo.RepoToRoleMapping do
  require Logger
  use Rbac.Repo.Schema
  alias Rbac.Repo.RbacRole
  import Ecto.Query

  @primary_key false
  schema "repo_to_role_mappings" do
    field(:org_id, :binary_id, primary_key: true)
    belongs_to(:admin_access_role, RbacRole)
    belongs_to(:push_access_role, RbacRole)
    belongs_to(:pull_access_role, RbacRole)
  end

  @doc """
    Given an organization id which owns a project, and your access rights on the repository that project is tied to,
    this function returns id of the role that should be assigned to you

    Arguments
      - org_id - Id of organization to which project belongs
      - admin_acess (boolean) Whehter you have admin access on specific repo
      - push_acess (boolean) Whehter you have push access on specific repo
      - pull_acess (boolean) Whehter you have pull access on specific repo
  """
  @spec get_project_role_from_repo_access_rights(String.t(), boolean(), boolean(), boolean()) ::
          String.t() | nil
  def get_project_role_from_repo_access_rights(org_id, admin_access, push_access, pull_access) do
    case get_repo_to_role_mapping(org_id) do
      nil ->
        nil

      mapping ->
        case {admin_access, push_access, pull_access} do
          {true, _, _} -> mapping.admin_access_role_id
          {false, true, _} -> mapping.push_access_role_id
          {false, false, true} -> mapping.pull_access_role_id
        end
    end
  end

  @doc """
    Returns
    - Repo_to_role_mapping for a specific organization.
  """
  def get_repo_to_role_mapping(org_id) do
    __MODULE__
    |> where([mapping], mapping.org_id == ^org_id)
    |> Rbac.Repo.one()
  end

  def create_mappings_from_yaml(org_id) do
    Logger.info("[RepoToRoleMapping] Creating mappings for org #{org_id}.")

    mappings = load_from_yaml()
    {:ok, admin_role} = RbacRole.get_role_by_name(mappings["admin"], "project_scope", org_id)
    {:ok, push_role} = RbacRole.get_role_by_name(mappings["push"], "project_scope", org_id)
    {:ok, pull_role} = RbacRole.get_role_by_name(mappings["pull"], "project_scope", org_id)

    %__MODULE__{
      org_id: org_id,
      admin_access_role_id: admin_role.id,
      push_access_role_id: push_role.id,
      pull_access_role_id: pull_role.id
    }
    |> Rbac.Repo.insert(
      on_conflict: {:replace_all_except, [:org_id]},
      conflict_target: [:org_id]
    )

    Logger.info("[RepoToRoleMapping] Finished creating mappings for org #{org_id}.")
  end

  @roles_yaml_path "./assets/roles.yaml"
  def load_from_yaml do
    {:ok, roles_yaml} = YamlElixir.read_from_file(@roles_yaml_path)
    roles_yaml["roles"]["repo_to_role_mappings"]
  end
end
