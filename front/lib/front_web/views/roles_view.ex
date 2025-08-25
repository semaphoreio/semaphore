defmodule FrontWeb.RolesView do
  use FrontWeb, :view
  alias InternalApi.RBAC.Scope

  @default_permissions ~w(organization.view project.view)

  def allow_role_creation?, do: !Front.ce?()

  def allow_project_roles?, do: !Front.ce?()

  def page_description do
    if allow_role_creation?() do
      "Manage roles available for your organization or projects. Create new user roles or edit permissions for existing ones."
    else
      "View roles available for your organization."
    end
  end

  def roles_action_message do
    if allow_role_creation?(), do: "Manage", else: "View"
  end

  def organization_roles(roles),
    do: roles |> Enum.filter(&(Scope.key(&1.scope) == :SCOPE_ORG)) |> sort_roles(:SCOPE_ORG)

  def project_roles(roles),
    do: Enum.filter(roles, &(Scope.key(&1.scope) == :SCOPE_PROJECT)) |> sort_roles(:SCOPE_PROJECT)

  def role_mapping_options(roles),
    do: roles |> project_roles() |> Enum.map(&{&1.name, &1.id})

  def item_link_path(conn, role) do
    if conn.assigns.permissions["organization.custom_roles.manage"],
      do: roles_path(conn, :edit, role.id),
      else: roles_path(conn, :show, role.id)
  end

  def permission_name(form), do: form.data.name || form.params["name"]
  def permission_desc(form), do: form.data.description || form.params["description"]

  def permission_checkbox(form, readonly?) do
    Phoenix.HTML.Form.checkbox(form, :granted,
      disabled: readonly? || permission_name(form) in @default_permissions
    )
  end

  def number_of_permissions([]), do: "No permissions"
  def number_of_permissions([_]), do: "1 permission"
  def number_of_permissions(permissions), do: "#{length(permissions)} permissions"

  def can_create_new_role?(conn, custom_roles_enabled?),
    do: conn.assigns.permissions["organization.custom_roles.manage"] && custom_roles_enabled?

  def new_role_btn_tooltip(conn, custom_roles_enabled?) do
    cond do
      !custom_roles_enabled? ->
        "Sorry, this feature is not enabled."

      !conn.assigns.permissions["organization.custom_roles.manage"] ->
        "You don't have permissions to create a new role."

      true ->
        ""
    end
  end

  defp sort_roles(roles, :SCOPE_PROJECT) do
    Enum.sort_by(roles, fn role ->
      case role do
        %{name: "Admin"} -> 0
        %{name: "Contributor"} -> 1
        %{name: "Reader"} -> 2
        _ -> 3
      end
    end)
  end

  defp sort_roles(roles, :SCOPE_ORG) do
    Enum.sort_by(roles, fn role ->
      case role do
        %{name: "Owner"} -> 0
        %{name: "Admin"} -> 1
        %{name: "Member"} -> 2
        _ -> 3
      end
    end)
  end
end
