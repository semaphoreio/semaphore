defmodule Rbac.Roles.Member do
  def role do
    %{
      id: "1cee59c8-055d-4dc7-807f-a008937a4b27",
      name: "Member",
      description:
        "Members can access the organization's homepage and the projects they are assigned to. However, they are not able to modify any settings.",
      permissions: [
        "organization.view",
        "organization.activity_monitor.view",
        "organization.self_hosted_agents.view",
        "organization.self_hosted_agents.manage",
        "organization.secrets.view",
        "organization.secrets.manage",
        "organization.notifications.view",
        "organization.notifications.manage",
        "organization.dashboards.manage",
        "organization.dashboards.view",
        "project.access.view",
        "project.artifacts.view",
        "project.artifacts.view_settings",
        "project.general_settings.view",
        "project.notifications.view",
        "project.repository_info.view",
        "project.scheduler.view",
        "project.secrets.view",
        "project.view"
      ]
    }
  end
end
