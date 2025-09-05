defmodule FrontWeb.EphemeralEnvironmentView do
  use FrontWeb, :view

  alias Front.Models.EphemeralEnvironment

  def render("index.json", %{environment_types: environment_types}) do
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
