defmodule Support.Stubs.PermissionPatrol do
  alias Support.Stubs.DB

  @all_organization_permissions "organization.okta.view,organization.okta.manage,organization.zendesk,organization.delete,organization.view,organization.secrets_policy_settings.manage,organization.secrets_policy_settings.view,organization.activity_monitor.view,organization.projects.create,organization.audit_logs.view,organization.audit_logs.manage,organization.people.view,organization.people.invite,organization.people.manage,organization.groups.view,organization.groups.manage,organization.custom_roles.manage,organization.self_hosted_agents.view,organization.self_hosted_agents.manage,organization.general_settings.view,organization.general_settings.manage,organization.secrets.view,organization.secrets.manage,organization.ip_allow_list.view,organization.ip_allow_list.manage,organization.notifications.view,organization.notifications.manage,organization.pre_flight_checks.view,organization.pre_flight_checks.manage,organization.plans_and_billing.view,organization.plans_and_billing.manage,organization.repo_to_role_mappers.manage,organization.dashboards.view,organization.dashboards.manage"
  @all_project_permissions "project.view,project.delete,project.access.view,project.access.manage,project.debug,project.secrets.view,project.secrets.manage,project.notifications.view,project.notifications.manage,project.insights.view,project.insights.manage,project.artifacts.view,project.artifacts.delete,project.artifacts.view_settings,project.artifacts.modify_settings,project.scheduler.view,project.scheduler.manage,project.general_settings.view,project.general_settings.manage,project.repository_info.view,project.repository_info.manage,project.deployment_targets.view,project.deployment_targets.manage,project.pre_flight_checks.view,project.pre_flight_checks.manage,project.workflow.view,project.workflow.manage,project.job.view,project.job.rerun,project.job.stop,project.job.port_forwarding,project.job.attach"

  def init do
    DB.add_table(:user_permissions_key_value_store, [:key, :value])

    __MODULE__.Grpc.init()
  end

  def all_organization_permissions, do: @all_organization_permissions
  def all_project_permissions, do: @all_project_permissions

  def add_all_permissions(org_id, user_id) do
    add_permissions(org_id, user_id, all_organization_permissions())
    add_permissions(org_id, user_id, all_project_permissions())
  end

  def add_permissions(org_id, user_id, permissions),
    do: add_permissions(org_id, user_id, permissions, "*")

  def add_permissions(org_id, user_id, permissions, project_id) when not is_list(permissions) do
    add_permissions(org_id, user_id, [permissions], project_id)
  end

  def add_permissions(org_id, user_id, permissions, project_id) do
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

      %InternalApi.PermissionPatrol.HasPermissionsResponse{
        has_permissions:
          Enum.reduce(permissions, %{}, fn permission, acc ->
            Map.put(acc, permission, all_permissions =~ permission)
          end)
      }
    end

    ###
    ### Helper funcs
    ###
    defp asked_permissions(project_id, permissions) do
      if permissions != [] do
        permissions
      else
        if project_id == "" do
          String.split(Support.Stubs.PermissionPatrol.all_organization_permissions(), ",")
        else
          String.split(Support.Stubs.PermissionPatrol.all_project_permissions(), ",")
        end
      end
    end
  end
end
