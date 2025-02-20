defmodule Rbac.Repo.OrgRoleToProjRoleMapping do
  require Logger
  use Rbac.Repo.Schema
  alias Rbac.Repo.RbacRole

  @primary_key false
  schema "org_role_to_proj_role_mappings" do
    belongs_to(:org_role, RbacRole, primary_key: true)
    belongs_to(:proj_role, RbacRole, primary_key: true)
  end

  def create_mappings_from_yaml(org_id) do
    Logger.info("[OrgToProjMappings] Creating mappings for org #{org_id}.")

    Enum.each(load_from_yaml(), fn role_yaml ->
      if role_yaml.maps_to != nil do
        {:ok, org_role} = RbacRole.get_role_by_name(role_yaml.name, "org_scope", org_id)
        {:ok, proj_role} = RbacRole.get_role_by_name(role_yaml.maps_to, "project_scope", org_id)

        %__MODULE__{
          org_role_id: org_role.id,
          proj_role_id: proj_role.id
        }
        |> Rbac.Repo.insert(
          on_conflict: {:replace, [:org_role_id, :proj_role_id]},
          conflict_target: [:org_role_id, :proj_role_id]
        )
      end
    end)

    Logger.info("[OrgToProjMappings] Finished creating mappings for org #{org_id}.")
  end

  @roles_yaml_path "./assets/roles.yaml"
  def load_from_yaml do
    {:ok, roles_yaml} = YamlElixir.read_from_file(@roles_yaml_path)

    Enum.map(roles_yaml["roles"]["org_scope"], fn role ->
      %{
        name: role["name"],
        maps_to: role["maps_to"]
      }
    end)
  end
end
