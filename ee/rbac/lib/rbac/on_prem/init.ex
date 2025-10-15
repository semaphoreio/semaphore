defmodule Rbac.OnPrem.Init do
  require Logger
  alias Rbac.Repo.RolePermissionBinding

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

    %Rbac.Repo.Scope{scope_name: "project_scope"}
    |> Rbac.Repo.insert(on_conflict: :nothing)

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

  defp ensure_application_started do
    case Application.ensure_all_started(:rbac) do
      {:ok, _} = result ->
        Logger.info("[OnPrem Init] Rbac application started successfully")
        result

      error ->
        Logger.error("[OnPrem Init] Failed to start Rbac application: #{inspect(error)}")
        error
    end
  end

  def upgrade_id_providers_for_1_5 do
    {:ok, _} = ensure_application_started()

    Logger.info("[OnPrem Init] Upgrading to 1.5 - Adding OKTA to allowed_id_providers")

    okta_integrations = Rbac.Repo.all(Rbac.Repo.OktaIntegration)

    Logger.info("[OnPrem Init] Found #{length(okta_integrations)} Okta integration(s)")

    Enum.each(okta_integrations, fn integration ->
      org =
        case Rbac.Api.Organization.find_by_id(integration.org_id) do
          {:ok, org} ->
            org

          {:error, reason} ->
            log_organization_not_found(integration.org_id, reason)
        end

      :ok = add_okta_to_organization(org)
    end)

    Logger.info("[OnPrem Init] Upgrade to 1.5 completed")
    :ok
  end

  defp add_okta_to_organization(org) do
    current_providers = org.allowed_id_providers || []

    cond do
      "okta" in current_providers ->
        Logger.info(
          "[OnPrem Init] Organization #{org.org_id} already has OKTA in allowed_id_providers"
        )

        :ok

      current_providers == [] ->
        update_organization_with_okta(org, ["oidc", "api_token", "okta"])

      true ->
        update_organization_with_okta(org, current_providers ++ ["okta"])
    end
  end

  defp update_organization_with_okta(org, updated_providers) do
    Logger.info(
      "[OnPrem Init] Adding OKTA to allowed_id_providers for organization #{org.org_id}"
    )

    updated_org = Map.put(org, :allowed_id_providers, updated_providers)

    case Rbac.Api.Organization.update(updated_org) do
      {:ok, _} ->
        Logger.info(
          "[OnPrem Init] Successfully added OKTA to allowed_id_providers for organization #{org.org_id}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[OnPrem Init] Failed to update allowed_id_providers for organization #{org.org_id}: #{inspect(reason)}"
        )

        exit({:shutdown, 1})
    end
  end

  defp log_organization_not_found(org_id, reason) do
    Logger.error("[OnPrem Init] Failed to find organization #{org_id}: #{inspect(reason)}")
    exit({:shutdown, 1})
  end

  def upgrade_roles_for_1_5 do
    Logger.info("[OnPrem Init] Updating roles for 1.5")

    result =
      with {:ok, _} <- ensure_application_started(),
           {:ok, org} <- get_unique_organization(),
           {:ok, org_scope} <- ensure_org_scope_exists(),
           {:ok, roles} <- ensure_required_roles_exist(org, org_scope.id),
           {:ok, permissions} <- ensure_required_permissions_exist() do
        do_upgrade_roles_for_1_5(org_scope, roles, permissions)
      end

    case result do
      {:ok, tx_result} ->
        Logger.info("[OnPrem Init] Updating roles for 1.5 completed successfully")
        {:ok, tx_result}

      {:error, reason} ->
        exit_upgrade_roles_failure(reason)

      {:error, reason, value} ->
        exit_upgrade_roles_failure({reason, value})

      other ->
        exit_upgrade_roles_failure(other)
    end
  end

  defp get_unique_organization do
    case Rbac.FrontRepo.Organization |> Rbac.FrontRepo.all() do
      [] ->
        Logger.error("[OnPrem Init] No organization found")
        {:error, :no_organization_found}

      [org] ->
        Logger.info("[OnPrem Init] Found organization #{org.id}")
        {:ok, org}

      orgs when is_list(orgs) ->
        Logger.error("[OnPrem Init] Multiple organizations found: #{length(orgs)}")
        {:error, :multiple_organizations_found}
    end
  end

  defp do_upgrade_roles_for_1_5(_org_scope, roles, permissions) do
    Rbac.Repo.transaction(fn ->
      try do
        permissions_list = permission_pairs(permissions)

        result =
          roles
          |> role_pairs()
          |> Enum.map(fn {role_name, role} ->
            ensure_role_permissions!(role_name, role, permissions_list)
          end)

        # Only refresh organization-level permissions cache since we only modified org-level roles
        {:ok, rbi} = Rbac.RoleBindingIdentification.new(project_id: :is_nil)
        Rbac.Store.UserPermissions.add_permissions(rbi)

        result
      rescue
        e in [Ecto.Query.CastError, Ecto.ConstraintError] ->
          Logger.error("[OnPrem Init] Database error during upgrade: #{inspect(e)}")
          Rbac.Repo.rollback(:database_error)

        e ->
          Logger.error("[OnPrem Init] Unexpected error during upgrade: #{inspect(e)}")
          Rbac.Repo.rollback(:unexpected_error)
      end
    end)
  end

  defp role_pairs(%{owner_role: owner_role, admin_role: admin_role}) do
    [
      {"Owner", owner_role},
      {"Admin", admin_role}
    ]
  end

  defp permission_pairs(%{view_perm: view_perm, manage_perm: manage_perm}) do
    [
      {"view", view_perm},
      {"manage", manage_perm}
    ]
  end

  defp ensure_role_permissions!(role_name, role, permissions) do
    Enum.map(permissions, fn {perm_name, perm} ->
      ensure_role_permission_binding!(role, role_name, perm, perm_name)
    end)
  end

  defp ensure_role_permission_binding!(role, role_name, perm, perm_name) do
    attrs = [rbac_role_id: role.id, permission_id: perm.id]

    binding =
      RolePermissionBinding
      |> Rbac.Repo.get_by(attrs)

    binding_after =
      case binding do
        nil ->
          %RolePermissionBinding{
            rbac_role_id: role.id,
            permission_id: perm.id
          }
          |> Rbac.Repo.insert!()

          Logger.info("[OnPrem Init] Added #{perm_name} permission to #{role_name} role")

        _ ->
          Logger.info("[OnPrem Init] #{role_name} role already has #{perm_name} permission")
          binding
      end

    if is_nil(binding_after) do
      Logger.error("[OnPrem Init] #{role_name} role does not have #{perm_name} permission")
      exit({:shutdown, 1})
    end

    :ok
  end

  defp exit_upgrade_roles_failure(reason) do
    Logger.error("[OnPrem Init] Upgrade to 1.5 service accounts failed: #{inspect(reason)}")
    exit({:shutdown, 1})
  end

  defp ensure_org_scope_exists do
    case Rbac.Repo.Scope |> Rbac.Repo.get_by(scope_name: "org_scope") do
      nil ->
        Logger.error("[OnPrem Init] org_scope not found")
        {:error, :org_scope_not_found}

      scope ->
        Logger.info("[OnPrem Init] Found org_scope")
        {:ok, scope}
    end
  end

  defp ensure_required_roles_exist(org, scope_id) do
    with {:ok, owner_role} <- get_role("Owner", scope_id, org.id),
         {:ok, admin_role} <- get_role("Admin", scope_id, org.id) do
      {:ok, %{owner_role: owner_role, admin_role: admin_role}}
    end
  end

  defp get_role(name, scope_id, org_id) do
    case Rbac.Repo.RbacRole
         |> Rbac.Repo.get_by(name: name, scope_id: scope_id, org_id: org_id) do
      nil ->
        Logger.error("[OnPrem Init] #{name} role not found for organization #{org_id}")
        {:error, :role_not_found}

      role ->
        Logger.info("[OnPrem Init] Found #{name} role for organization #{org_id}")
        {:ok, role}
    end
  end

  defp ensure_required_permissions_exist do
    Logger.info("[OnPrem Init] Updating permissions with descriptions")
    Rbac.Repo.Permission.insert_default_permissions()

    with {:ok, view_perm} <- get_permission("organization.service_accounts.view"),
         {:ok, manage_perm} <- get_permission("organization.service_accounts.manage") do
      {:ok, %{view_perm: view_perm, manage_perm: manage_perm}}
    end
  end

  defp get_permission(name) do
    case Rbac.Repo.Permission |> Rbac.Repo.get_by(name: name) do
      nil ->
        Logger.error("[OnPrem Init] #{name} permission not found")
        {:error, :permission_not_found}

      permission ->
        Logger.info("[OnPrem Init] Found #{name} permission")
        {:ok, permission}
    end
  end
end
