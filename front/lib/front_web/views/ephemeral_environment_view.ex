defmodule FrontWeb.EphemeralEnvironmentView do
  use FrontWeb, :view

  alias Front.Models.EphemeralEnvironment

  def ephemeral_environments_config(conn) do
    # Use __ID__ as placeholder for client-side replacement
    placeholder_id = "__ID__"

    %{
      org_id: conn.assigns.organization_id,
      can_manage: conn.assigns.permissions["organization.ephemeral_environments.manage"] || false,
      can_view: conn.assigns.permissions["organization.ephemeral_environments.view"] || false,
      # TODO: Load available projects
      projects: [],
      base_path: "/ephemeral_environments",
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
        update: %{
          method: "put",
          path: ephemeral_environment_path(conn, :update, placeholder_id, format: "json")
        },
        delete: %{
          method: "delete",
          path: ephemeral_environment_path(conn, :delete, placeholder_id, format: "json")
        },
        cordon: %{
          method: "post",
          path: ephemeral_environment_path(conn, :cordon, placeholder_id, format: "json")
        }
      }
    }
  end

  def render("list.json", %{environment_types: environment_types}) do
    %{
      environment_types: Enum.map(environment_types, &environment_type_json/1)
    }
  end

  def render("show.json", %{environment_type: environment_type = %EphemeralEnvironment{}}) do
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
      max_number_of_instances: environment_type.max_number_of_instances
    }
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(datetime = %DateTime{}) do
    DateTime.to_iso8601(datetime)
  end
end
