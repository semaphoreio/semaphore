defmodule Rbac.Permissions do
  alias InternalApi.RBAC

  def construct_grpc_permission(permission) do
    %RBAC.Permission{
      id: permission.id,
      name: permission.name,
      description: permission.description,
      scope: map_permission_scope_to_grpc_enum(permission.name)
    }
  end

  defp map_permission_scope_to_grpc_enum(permission_name) do
    scope = get_permission_scope(permission_name)

    case scope do
      "organization" -> RBAC.Scope.value(:SCOPE_ORG)
      "project" -> RBAC.Scope.value(:SCOPE_PROJECT)
      _ -> RBAC.Scope.value(:SCOPE_UNSPECIFIED)
    end
  end

  def list_organization_permissions do
    list()
    |> Enum.filter(&(get_permission_scope(&1.name) == "organization"))
  end

  def list_project_permissions do
    list()
    |> Enum.filter(&(get_permission_scope(&1.name) == "project"))
  end

  def organization_permission?(permission_name) do
    get_permission_scope(permission_name) == "organization"
  end

  def project_permission?(permission_name) do
    get_permission_scope(permission_name) == "project"
  end

  defp get_permission_scope(permission_name) do
    [scope | _] = String.split(permission_name, ".")
    scope
  end

  def list do
    [
      %{
        id: "c3427048-8fee-46f8-af14-cb6d37c3ddd7",
        name: "organization.delete",
        description: "Delete the organization."
      },
      %{
        id: "78eaf21d-da16-44f2-9271-be78993f37f4",
        name: "organization.view",
        description:
          "Access to the organization. This permission is needed to access any page within the organization domain."
      },
      %{
        id: "0bc1cd2a-63ad-487a-91f8-7b3787ce043c",
        name: "organization.activity_monitor.view",
        description: "View organization's activity monitor."
      },
      %{
        id: "e9eb8661-9141-4251-843e-8c91af827c38",
        name: "organization.projects.create",
        description: "Create a new project within the organization."
      },
      %{
        id: "17819d8e-6c93-4d77-b978-ac38b261b819",
        name: "organization.people.view",
        description:
          "View list of people within the organization, together with the roles they have."
      },
      %{
        id: "b613af17-db4d-4acf-ac4e-5557787fbf3d",
        name: "organization.people.invite",
        description: "Invite new people to the organization."
      },
      %{
        id: "77122073-054f-4095-a118-dd3fe1ab2ef4",
        name: "organization.people.manage",
        description:
          "Remove people from the organization, or change their roles within the organization."
      },
      %{
        id: "26705995-67f0-4ab3-9bfb-f2e339f33472",
        name: "organization.change_owner",
        description: "Change the owner of the organization."
      },
      %{
        id: "9d97e56f-12e5-41a0-8291-468512c4cbdb",
        name: "organization.custom_roles.view",
        description: "View roles within the organization and permissions they carry."
      },
      %{
        id: "5370af53-ed6c-4236-93cd-39e96a53632e",
        name: "organization.self_hosted_agents.view",
        description: "View the list of self-hosted agents within the organization."
      },
      %{
        id: "40e1cad8-6e48-4705-b098-fda472b267d7",
        name: "organization.self_hosted_agents.manage",
        description: "Manage self-hosted agents within the organization."
      },
      %{
        id: "c90e8d07-195d-42ce-9fd3-a65985418080",
        name: "organization.general_settings.view",
        description: "View general settings for the organization."
      },
      %{
        id: "f93f7d87-8aca-44e7-91c8-a93ed94cca74",
        name: "organization.general_settings.manage",
        description: "Manage general settings of the organization."
      },
      %{
        id: "26aa0da1-c2ea-4a2b-8266-54b8549037c1",
        name: "organization.secrets.view",
        description: "View secrets within the organization."
      },
      %{
        id: "f24cae19-3fd0-4684-ba57-56e2b42f2912",
        name: "organization.secrets.manage",
        description: "Manage secrets within the organization."
      },
      %{
        id: "03cc858e-c7e8-4c54-b25d-94239d1ba73f",
        name: "organization.notifications.view",
        description: "View organization notification settings."
      },
      %{
        id: "982f27f1-a177-480c-9d17-0f516ef9500d",
        name: "organization.notifications.manage",
        description: "Modify organization notification settings."
      },
      %{
        id: "ac0f5b05-f2e8-4b43-bf4c-88b1f6b56c91",
        name: "organization.pre_flight_checks.view",
        description: "View pre-flight checks within the organization."
      },
      %{
        id: "fb959fee-e287-4c67-967e-4f5f211a654f",
        name: "organization.pre_flight_checks.manage",
        description: "Modify pre-flight checks within the organization."
      },
      %{
        id: "cdfdca2f-dcf2-461c-94e6-911b55da62ce",
        name: "organization.dashboards.view",
        description: "View the existing dashboards within the organization."
      },
      %{
        id: "70405408-6cf5-47ec-8f48-910ca4c322e0",
        name: "organization.dashboards.manage",
        description: "Create new dashboard views."
      },
      %{
        id: "c530356b-c90e-473f-97b5-ea4538f95364",
        name: "organization.instance_git_integration.manage",
        description: "Manage the instance Git integration settings."
      },
      %{
        id: "c530356b-c90e-473f-97b5-ea4538f95365",
        name: "organization.service_accounts.view",
        description: "View service accounts within the organization."
      },
      %{
        id: "c530356b-c90e-473f-97b5-ea4538f95366",
        name: "organization.service_accounts.manage",
        description: "Manage service accounts within the organization."
      },
      %{
        id: "bcaf879d-987f-42d7-9c89-f10911db6041",
        name: "project.view",
        description:
          "Access the project. This permission is needed to see any page within the project."
      },
      %{
        id: "54d100e5-68fc-47bd-acc3-ddf25f770a46",
        name: "project.delete",
        description: "Delete the project."
      },
      %{
        id: "c4becb88-42d2-49ad-96dd-ae6ad20ffa33",
        name: "project.access.view",
        description: "View people, groups and bots that have acces to the project."
      },
      %{
        id: "b8d4c716-3669-440b-a085-18135d09856f",
        name: "project.access.manage",
        description: "Manage who has access to the project."
      },
      %{
        id: "3291ac5e-8b16-4f96-a02d-506e78838b6e",
        name: "project.secrets.view",
        description: "View existing secrets related to the project."
      },
      %{
        id: "133f8c9a-e576-47ce-afc1-99ff1deb4e6b",
        name: "project.secrets.manage",
        description: "Manage project secrets."
      },
      %{
        id: "c451f290-fa33-46ed-8bdc-ca6564f28619",
        name: "project.notifications.view",
        description: "View project notifications."
      },
      %{
        id: "f5a91d70-a34e-4198-b11b-1d3c0371e02a",
        name: "project.notifications.manage",
        description: "Manage project notifications."
      },
      %{
        id: "d72ebd9b-154f-4851-bf69-672390948346",
        name: "project.artifacts.view",
        description: "Access the artifacts on the project, workflow and job level."
      },
      %{
        id: "b6a01085-556b-4eee-b8dc-96b8254040dc",
        name: "project.artifacts.delete",
        description: "Remove individual artifacts."
      },
      %{
        id: "40851048-ad90-4c38-ac39-902b7a53e7f2",
        name: "project.artifacts.view_settings",
        description: "View artifact settings."
      },
      %{
        id: "c91a41b6-bc3e-4514-ac80-2bbf44c2547a",
        name: "project.artifacts.modify_settings",
        description: "Modify artifact settings, such as retention policy."
      },
      %{
        id: "8ae5a38f-fb56-42b4-ab8a-543fe5a7d66e",
        name: "project.scheduler.view",
        description: "View tasks within the project."
      },
      %{
        id: "c4b21edf-e3dc-4335-82a8-c510bd82f179",
        name: "project.scheduler.manage",
        description: "Modify project tasks."
      },
      %{
        id: "305ac3e7-c136-456c-ab9d-cd7b055b5cb5",
        name: "project.scheduler.run_manually",
        description: "Trigger manual runs of any existing tasks."
      },
      %{
        id: "b3befcb3-eb1b-4584-84cc-0dd471057f19",
        name: "project.general_settings.view",
        description: "View general settings for the project."
      },
      %{
        id: "d066e5ec-cd88-4a8f-abdd-51b36165304b",
        name: "project.general_settings.manage",
        description: "Modify general settings for the project."
      },
      %{
        id: "7c6485c1-1d63-4fcd-82b6-fcf083dd6809",
        name: "project.repository_info.view",
        description: "View git repository information."
      },
      %{
        id: "d05d075d-7deb-43dd-9023-e762799e550b",
        name: "project.repository_info.manage",
        description: "Modify git repository information."
      },
      %{
        id: "dea9ca7d-b5de-4f48-b475-1a47382617e8",
        name: "project.workflow.manage",
        description: "Change workflow definition (jobs that will run within the workflow)."
      },
      %{
        id: "325311b5-31bc-4d62-82e9-6b74124f5575",
        name: "project.job.rerun",
        description: "Manually rerun jobs or entire workflows"
      },
      %{
        id: "cb11135c-c305-40a4-b497-13610593813e",
        name: "project.job.stop",
        description: "Manually stop running jobs or workflows."
      },
      %{
        id: "cd5492c6-a527-45d6-9c50-c429bf874b95",
        name: "project.job.attach",
        description: "SSH into the running job, or start a debug session."
      }
    ]
  end
end
