defmodule FrontWeb.EphemeralEnvironmentView do
  use FrontWeb, :view
  alias Front.Models.EphemeralEnvironment

  def ephemeral_environments_config(conn) do
    placeholder_id = "__ID__"
    placeholder_search = "__SEARCH__"

    %{
      org_id: conn.assigns.organization_id,
      can_manage: conn.assigns.permissions["organization.ephemeral_environments.manage"] || false,
      can_view: conn.assigns.permissions["organization.ephemeral_environments.view"] || false,
      base_url: ephemeral_environment_path(conn, :index),

      # API URLs using Url<T> pattern with method and path
      api_urls: %{
        list: %{
          method: "get",
          path: ephemeral_environment_path(conn, :list, format: "json")
        },
        create: %{
          method: "post",
          path: ephemeral_environment_path(conn, :create, format: "json")
        },
        show: %{
          method: "get",
          path: ephemeral_environment_path(conn, :show, placeholder_id, format: "json")
        },
        delete: %{
          method: "delete",
          path: ephemeral_environment_path(conn, :delete, placeholder_id, format: "json")
        },
        cordon: %{
          method: "post",
          path: ephemeral_environment_path(conn, :cordon, placeholder_id, format: "json")
        },
        update: %{
          method: "put",
          path: ephemeral_environment_path(conn, :update, placeholder_id, format: "json")
        },
        projects_list: %{
          method: "get",
          path: project_path(conn, :index, format: "json")
        },
        users_list: %{
          method: "get",
          path: people_path(conn, :index) <> "?type=user&search=#{placeholder_search}"
        },
        groups_list: %{
          method: "get",
          path: people_path(conn, :index) <> "?type=group&search=#{placeholder_search}"
        },
        service_accounts_list: %{
          method: "get",
          path: people_path(conn, :index) <> "?type=service_account&search=#{placeholder_search}"
        }
      }
    }
  end

  def render("list.json", %{environment_types: environment_types}) do
    %{
      environment_types: Enum.map(environment_types, &environment_type_json/1)
    }
  end

  def render("show.json", %{environment_type: environment_type}) do
    environment_type_json(environment_type)
  end

  defp environment_type_json(environment_type = %EphemeralEnvironment{}) do
    %{
      id: environment_type.id,
      org_id: environment_type.org_id,
      name: environment_type.name,
      description: environment_type.description,
      created_by: environment_type.created_by,
      last_updated_by: environment_type.last_updated_by,
      created_at: format_datetime(environment_type.created_at),
      updated_at: format_datetime(environment_type.updated_at),
      state: environment_type.state,
      maxInstances: environment_type.max_number_of_instances,
      stages: environment_type.stages || [],
      environmentContext: environment_type.environment_context || [],
      projectAccess:
        map_project_access(environment_type.accessible_project_ids, environment_type.org_id),
      ttlConfig: environment_type.ttl_config || %{enabled: false}
    }
  end

  defp map_project_access(nil, _org_id), do: []
  defp map_project_access([], _org_id), do: []

  defp map_project_access(project_ids, org_id) do
    projects = Front.Models.Project.find_many_by_ids(project_ids, org_id)
    projects_map = Map.new(projects, fn project -> {project.id, project} end)

    Enum.map(project_ids, fn id ->
      case Map.get(projects_map, id) do
        nil ->
          %{projectId: id, projectName: id, projectDescription: nil}

        project ->
          %{
            projectId: id,
            projectName: project.name,
            projectDescription: project.description
          }
      end
    end)
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(datetime = %DateTime{}) do
    DateTime.to_iso8601(datetime)
  end
end
