defmodule FrontWeb.McpOAuthView do
  use FrontWeb, :view

  def display_user_name(user, fallback_user_id) do
    cond do
      is_nil(user) -> fallback_user_id
      is_binary(Map.get(user, :name)) and String.trim(user.name) != "" -> user.name
      true -> fallback_user_id
    end
  end

  def preselected_org_permission?(default_org_grants, org_id, permission) do
    case Map.get(default_org_grants, org_id) do
      nil -> false
      org_grant -> Map.get(org_grant, permission, false)
    end
  end

  def preselected_project_permission?(default_project_grants, project_id, permission) do
    case Map.get(default_project_grants, project_id) do
      nil -> false
      project_grant -> Map.get(project_grant, permission, false)
    end
  end
end
