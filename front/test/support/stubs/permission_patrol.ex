defmodule Support.Stubs.PermissionPatrol do
  alias Support.Stubs.DB

  @all_organization_permissions "organization.custom_roles.view,organization.custom_roles.manage,organization.okta.view,organization.okta.manage,organization.contact_support,organization.delete,organization.view,organization.secrets_policy_settings.manage,organization.secrets_policy_settings.view,organization.activity_monitor.view,organization.projects.create,organization.audit_logs.view,organization.audit_logs.manage,organization.people.view,organization.people.invite,organization.people.manage,organization.groups.view,organization.groups.manage,organization.custom_roles.manage,organization.self_hosted_agents.view,organization.self_hosted_agents.manage,organization.general_settings.view,organization.general_settings.manage,organization.secrets.view,organization.secrets.manage,organization.ip_allow_list.view,organization.ip_allow_list.manage,organization.notifications.view,organization.notifications.manage,organization.pre_flight_checks.view,organization.pre_flight_checks.manage,organization.plans_and_billing.view,organization.plans_and_billing.manage,organization.repo_to_role_mappers.manage,organization.dashboards.view,organization.dashboards.manage,organization.instance_git_integration.manage,organization.service_accounts.view,organization.service_accounts.manage"
  @all_project_permissions "project.view,project.delete,project.access.view,project.access.manage,project.debug,project.secrets.view,project.secrets.manage,project.notifications.view,project.notifications.manage,project.insights.view,project.insights.manage,project.artifacts.view,project.artifacts.delete,project.artifacts.view_settings,project.artifacts.modify_settings,project.scheduler.view,project.scheduler.manage,project.scheduler.run_manually,project.general_settings.view,project.general_settings.manage,project.repository_info.view,project.repository_info.manage,project.deployment_targets.view,project.deployment_targets.manage,project.pre_flight_checks.view,project.pre_flight_checks.manage,project.workflow.view,project.workflow.manage,project.job.view,project.job.rerun,project.job.stop,project.job.port_forwarding,project.job.attach"

  def init do
    DB.add_table(:user_permissions_key_value_store, [:key, :value])

    __MODULE__.Grpc.init()
  end

  def remove_all_permissions, do: DB.clear(:user_permissions_key_value_store)

  def allow_everything do
    org_id = Support.Stubs.Organization.default_org_id()
    user_id = Support.Stubs.User.default_user_id()
    allow_everything(org_id, user_id)
  end

  def allow_everything(org_id, user_id) do
    add_permissions(
      org_id,
      user_id,
      get_all_org_permissions() <> "," <> get_all_project_permissions()
    )
  end

  def allow_everything_except(org_id, user_id, permission) when not is_list(permission),
    do: allow_everything_except(org_id, user_id, [permission])

  def allow_everything_except(org_id, user_id, permissions) do
    all_permissions = get_all_org_permissions() <> "," <> get_all_project_permissions()

    filtered_permissions =
      Enum.reduce(permissions, all_permissions, fn perm_to_remove, acc ->
        String.replace(acc, perm_to_remove, "")
      end)

    add_permissions(org_id, user_id, filtered_permissions)
  end

  def add_permissions(org_id, user_id, permissions),
    do: add_permissions(org_id, user_id, "*", permissions)

  def add_permissions(org_id, user_id, project_id, permissions) when not is_list(permissions) do
    add_permissions(org_id, user_id, project_id, [permissions])
  end

  def add_permissions(org_id, user_id, project_id, permissions) do
    key = "user:#{user_id}_org:#{org_id}_project:#{project_id}"
    new_permissions = Enum.join(permissions, ",")

    exsisting_permissions =
      case DB.find_by(:user_permissions_key_value_store, :key, key) do
        nil -> ""
        record -> record.value
      end

    DB.upsert(
      :user_permissions_key_value_store,
      %{
        key: key,
        value: new_permissions <> "," <> exsisting_permissions
      },
      :key
    )
  end

  def get_all_org_permissions, do: @all_organization_permissions
  def get_all_project_permissions, do: @all_project_permissions

  defmodule Grpc do
    def init do
      GrpcMock.stub(PermissionPatrolMock, :has_permissions, &__MODULE__.has_permissions/2)
    end

    def has_permissions(req, _) do
      org_id = req.org_id
      project_id = req.project_id
      user_id = req.user_id
      permissions = asked_permissions(project_id, req.permissions)

      keys =
        ["user:#{user_id}_org:#{org_id}_project:*"] ++
          if project_id == "" do
            []
          else
            ["user:#{user_id}_org:#{org_id}_project:#{project_id}"]
          end

      all_permissions =
        Enum.reduce(keys, "", fn key, acc ->
          permissions =
            case DB.find_by(:user_permissions_key_value_store, :key, key) do
              nil -> ""
              record -> record.value
            end

          acc <> permissions
        end)

      InternalApi.PermissionPatrol.HasPermissionsResponse.new(
        has_permissions:
          Enum.reduce(permissions, %{}, fn permission, acc ->
            if Application.get_env(:front, :environment) == :dev do
              Map.put(acc, permission, true)
            else
              Map.put(acc, permission, all_permissions =~ permission)
            end
          end)
      )
    end

    ###
    ### Helper funcs
    ###

    defp asked_permissions(project_id, permissions) do
      if permissions != [] do
        permissions
      else
        if project_id == "" do
          String.split(Support.Stubs.PermissionPatrol.get_all_org_permissions(), ",")
        else
          String.split(Support.Stubs.PermissionPatrol.get_all_project_permissions(), ",")
        end
      end
    end
  end
end
