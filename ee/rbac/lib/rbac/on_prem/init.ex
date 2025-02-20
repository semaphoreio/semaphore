defmodule Rbac.OnPrem.Init do
  require Logger

  def init(retry_count \\ 0) do
    if retry_count > 5 do
      Logger.info("[OnPrem Init] Retried 5 times, exiting...")
      exit({:shutdown, 1})
    end

    Logger.info("[OnPrem Init] Initializing data for onprem instance")

    org_username = fetch_env_or_die("ORGANIZATION_SEED_ORG_USERNAME")

    try do
      {:ok, org} = Rbac.Api.Organization.find_by_username(org_username)
      Logger.info("[OnPrem Init] Organization found: #{org.name}, id: #{org.org_id}")

      init_org_rbac_data(org.org_id)
      assign_owner_role(org.owner_id, org.org_id)
    rescue
      e ->
        Logger.error(
          "[OnPrem Init] Organization not found, retrying in 10 seconds: #{inspect(e)}"
        )

        :timer.sleep(10_000)
        init(retry_count + 1)
    end
  end

  defp init_org_rbac_data(org_id) do
    Logger.info("[RBAC Seed Data] Inserting scopes")
    %Rbac.Repo.Scope{scope_name: "org_scope"} |> Rbac.Repo.insert(on_conflict: :nothing)
    %Rbac.Repo.Scope{scope_name: "project_scope"} |> Rbac.Repo.insert(on_conflict: :nothing)

    Rbac.Repo.Permission.insert_default_permissions()
    Rbac.Store.RbacRole.create_default_roles_for_organization(org_id)
    Rbac.Repo.RepoToRoleMapping.create_mappings_from_yaml(org_id)
  end

  defp assign_owner_role(user_id, org_id) do
    Logger.info("[OnPrem Init] Assigning owner role to the default user")

    {:ok, owner_role} = Rbac.Repo.RbacRole.get_role_by_name("Owner", "org_scope", org_id)
    {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: org_id)

    case Rbac.RoleManagement.assign_role(rbi, owner_role.id, :manually_assigned) do
      {:ok, nil} ->
        :ok

      {:error, err_msg} ->
        Logger.info(
          "[OnPrem Init] Error while assigning owner role to the default user: #{inspect(err_msg)}"
        )

        exit({:shutdown, 1})
    end
  end

  defp fetch_env_or_die(env_name) do
    case System.fetch_env(env_name) do
      {:ok, value} ->
        value

      :error ->
        Logger.info("ERROR: #{env_name} environment variable not provided")
        exit({:shutdown, 1})
    end
  end

  def upgrade_to_1_2 do
    Logger.info("[OnPrem Init] Upgrading to 1.2")

    org = Rbac.FrontRepo.Organization |> Rbac.FrontRepo.one()

    init_org_rbac_data(org.id)

    Rbac.Store.UserPermissions.recalculate_entire_cache()
    Rbac.Store.ProjectAccess.recalculate_entire_key_value_store()
  end
end
