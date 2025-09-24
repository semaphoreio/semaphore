defmodule FrontWeb.RolesController do
  @moduledoc false
  use FrontWeb, :controller
  alias Front.Async
  alias Front.Audit
  require Logger

  alias Front.RBAC.Role
  alias Front.RBAC.RoleManagement

  @read_permission "organization.view"
  @read_actions ~w(index show)a

  @write_permission "organization.custom_roles.manage"
  @write_actions ~w(new edit create update delete)a

  @valid_scopes ~w(organization project)
  @audit_actions ~w(Added Modified Removed)a

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, [permissions: @read_permission] when action in @read_actions)
  plug(FrontWeb.Plugs.PageAccess, [permissions: @write_permission] when action in @write_actions)
  plug(FrontWeb.Plugs.Header)

  plug(:put_layout, :organization_settings)
  plug(:authorize_feature when action in @write_actions)

  @watchman_prefix "settings.roles.endpoint"

  def index(conn, _params) do
    Watchman.benchmark(watchman_name(:index, :duration), fn ->
      {:ok, roles} = Async.await(fetch_roles_async(conn.assigns.organization_id))

      if conn.assigns.permissions["organization.custom_roles.view"] do
        render(conn, "index.html",
          roles: roles,
          title: "Roles",
          feature_enabled?: feature_state(conn) == :enabled,
          notice: get_flash(conn, :notice),
          alert: get_flash(conn, :alert)
        )
      else
        render(conn, "no_access.html",
          title: "Roles",
          notice: get_flash(conn, :notice),
          alert: get_flash(conn, :alert)
        )
      end
    end)
  end

  def show(conn, _params = %{"role_id" => role_id}) do
    Watchman.benchmark(watchman_name(:show, :duration), fn ->
      async_role = fetch_role_async(conn.assigns.organization_id, role_id)

      case Async.await(async_role) do
        {:ok, role} ->
          async_roles = fetch_roles_async(conn.assigns.organization_id)
          scope = if Front.ce?(), do: "", else: role.scope
          async_permissions = fetch_permissions_async(scope)

          {:ok, roles} = Async.await(async_roles)
          {:ok, permissions} = Async.await(async_permissions)

          if conn.assigns.permissions["organization.custom_roles.view"] do
            render_show(conn, {:view, role},
              changeset: role |> Role.from_api(permissions) |> Role.changeset(%{}),
              roles: roles,
              permissions: permissions
            )
          else
            render(conn, "no_access.html",
              title: "Role overview・#{role.name}",
              notice: get_flash(conn, :notice),
              alert: get_flash(conn, :alert)
            )
          end

        {:exit, {%GRPC.RPCError{status: 5}, _st}} ->
          render_404(conn)
      end
    end)
  end

  def show(conn, _params), do: render_404(conn)

  def new(conn, _params = %{"scope" => scope}) when scope in @valid_scopes do
    Watchman.benchmark(watchman_name(:new, :duration), fn ->
      {:ok, roles} = Async.await(fetch_roles_async(conn.assigns.organization_id))
      {:ok, permissions} = Async.await(fetch_permissions_async(scope))
      role = Role.new(scope: scope, permissions: permissions)

      render_show(conn, :create,
        changeset: Role.changeset(role, %{}),
        roles: roles,
        permissions: permissions
      )
    end)
  end

  def new(conn, _params), do: render_404(conn)

  def edit(conn, _params = %{"role_id" => role_id}) do
    Watchman.benchmark(watchman_name(:edit, :duration), fn ->
      async_role = fetch_role_async(conn.assigns.organization_id, role_id)

      case Async.await(async_role) do
        {:ok, role} ->
          async_roles = fetch_roles_async(conn.assigns.organization_id)
          async_permissions = fetch_permissions_async(role.scope)

          {:ok, roles} = Async.await(async_roles)
          {:ok, permissions} = Async.await(async_permissions)

          render_show(conn, if(role.readonly, do: {:view, role}, else: {:update, role}),
            changeset: role |> Role.from_api(permissions) |> Role.changeset(%{}),
            roles: roles,
            permissions: permissions
          )

        {:exit, {%GRPC.RPCError{status: 5}, _st}} ->
          render_404(conn)
      end
    end)
  end

  def edit(conn, _params), do: render_404(conn)

  def create(conn, _params = %{"role" => role_params}) do
    Watchman.benchmark(watchman_name(:create, :duration), fn ->
      log_data = log_data_closure(conn.assigns.organization_id, conn.assigns.user_id, :create)
      {:ok, roles} = Async.await(fetch_roles_async(conn.assigns.organization_id))
      {:ok, permissions} = Async.await(fetch_permissions_async(role_params["scope"]))

      used_names = MapSet.new(roles, & &1.name)
      changeset = Role.changeset(Role.new(), role_params, used_names: used_names)

      with {:ok, role} <- Ecto.Changeset.apply_action(changeset, :insert),
           {:ok, %{role_id: role_id}} <-
             RoleManagement.modify_role(
               Role.to_api(role,
                 org_id: conn.assigns.organization_id,
                 permissions: permissions,
                 roles: roles
               ),
               conn.assigns.user_id
             ) do
        Watchman.increment(watchman_name(:create, :success))
        audit_log(conn, :Added, role_id)

        conn
        |> put_flash(:notice, "Role created successfully")
        |> redirect(to: roles_path(conn, :index))
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.debug(fn -> "[Custom Roles] Invalid data: #{inspect(changeset)}" end)

          conn
          |> put_flash(:alert, "Check provided data for errors")
          |> render_show(:create,
            changeset: changeset,
            roles: roles,
            permissions: permissions
          )

        {:error, reason} ->
          Watchman.increment(watchman_name(:create, :failure))
          Logger.error(log_data.(reason))

          conn
          |> put_flash(:alert, reason.message)
          |> render_show(:create,
            changeset: changeset,
            roles: roles,
            permissions: permissions
          )
      end
    end)
  end

  def create(conn, _params), do: render_404(conn)

  def update(conn, _params = %{"role_id" => role_id, "role" => role_params}) do
    Watchman.benchmark(watchman_name(:update, :duration), fn ->
      log_data = log_data_closure(conn.assigns.organization_id, conn.assigns.user_id, :update)
      async_role = fetch_role_async(conn.assigns.organization_id, role_id)

      case Async.await(async_role) do
        {:ok, role} ->
          {:ok, roles} = Async.await(fetch_roles_async(conn.assigns.organization_id))
          {:ok, permissions} = Async.await(fetch_permissions_async(role.scope))
          used_names = roles |> Enum.reject(&(&1.id == role_id)) |> MapSet.new(& &1.name)

          changeset =
            Role.changeset(Role.from_api(role, permissions), role_params, used_names: used_names)

          with {:ok, role} <- Ecto.Changeset.apply_action(changeset, :update),
               {:ok, %{role_id: role_id}} <-
                 RoleManagement.modify_role(
                   Role.to_api(role,
                     org_id: conn.assigns.organization_id,
                     permissions: permissions,
                     roles: roles
                   ),
                   conn.assigns.user_id
                 ) do
            Watchman.increment(watchman_name(:update, :success))
            audit_log(conn, :Modified, role_id)

            conn
            |> put_flash(:notice, "Role updated successfully")
            |> redirect(to: roles_path(conn, :index))
          else
            {:error, %Ecto.Changeset{} = changeset} ->
              Logger.debug(fn -> "[Custom Roles] Invalid data: #{inspect(changeset)}" end)

              conn
              |> put_flash(:alert, "Check provided data for errors")
              |> render_show({:update, role},
                changeset: changeset,
                roles: roles,
                permissions: permissions
              )

            {:error, reason} ->
              Logger.error(log_data.(reason))
              Watchman.increment(watchman_name(:update, :failure))

              conn
              |> put_flash(:alert, reason.message)
              |> render_show({:update, role},
                changeset: changeset,
                roles: roles,
                permissions: permissions
              )
          end

        {:exit, {%GRPC.RPCError{status: 5}, _st}} ->
          render_404(conn)
      end
    end)
  end

  def update(conn, _params), do: render_404(conn)

  def delete(conn, _params = %{"role_id" => role_id}) do
    Watchman.benchmark(watchman_name(:delete, :duration), fn ->
      log_data = log_data_closure(conn.assigns.organization_id, conn.assigns.user_id, :delete)

      with {:ok, _role} <- Async.await(fetch_role_async(conn.assigns.organization_id, role_id)),
           {:ok, %{role_id: role_id}} <-
             RoleManagement.destroy_role(
               conn.assigns.organization_id,
               conn.assigns.user_id,
               role_id
             ) do
        Watchman.increment(watchman_name(:delete, :success))
        audit_log(conn, :Removed, role_id)

        conn
        |> put_flash(:notice, "Role removed successfully")
        |> redirect(to: roles_path(conn, :index))
      else
        {:error, reason} ->
          Logger.error(log_data.(reason))
          Watchman.increment(watchman_name(:delete, :failure))

          conn
          |> put_flash(:alert, reason.message)
          |> redirect(to: roles_path(conn, :index))

        {:exit, {%GRPC.RPCError{status: 5}, _st}} ->
          conn
          |> put_flash(:notice, "Role removed successfully")
          |> redirect(to: roles_path(conn, :index))
      end
    end)
  end

  defp fetch_roles_async(organization_id),
    do:
      Async.run(fn ->
        case RoleManagement.list_possible_roles(organization_id) do
          {:ok, roles} -> roles
          {:error, error} -> raise error
        end
      end)

  defp fetch_role_async(organization_id, role_id),
    do:
      Async.run(fn ->
        case RoleManagement.describe_role(organization_id, role_id) do
          {:ok, role} -> role
          {:error, error} -> raise error
        end
      end)

  defp fetch_permissions_async(scope),
    do:
      Async.run(fn ->
        case RoleManagement.list_existing_permissions(scope) do
          {:ok, permissions} -> permissions
          {:error, error} -> raise error
        end
      end)

  defp render_show(conn, {:view, role}, assigns) do
    assigns
    |> Keyword.put(:readonly, true)
    |> Keyword.put(:role_id, role.id)
    |> Keyword.put(:title, "Role overview・#{role.name}")
    |> Keyword.put(:form_path, roles_path(conn, :show, role.id))
    |> Keyword.put(:form_method, :get)
    |> render_show(conn)
  end

  defp render_show(conn, :create, assigns) do
    assigns
    |> Keyword.put(:readonly, false)
    |> Keyword.put(:role_id, nil)
    |> Keyword.put(:title, "Create a new role")
    |> Keyword.put(:form_path, roles_path(conn, :create))
    |> Keyword.put(:form_method, :post)
    |> render_show(conn)
  end

  defp render_show(conn, {:update, role}, assigns) do
    assigns
    |> Keyword.put(:readonly, false)
    |> Keyword.put(:role_id, role.id)
    |> Keyword.put(:title, "Edit role・#{role.name}")
    |> Keyword.put(:form_path, roles_path(conn, :update, role.id))
    |> Keyword.put(:form_method, :put)
    |> render_show(conn)
  end

  defp render_show(assigns, conn) do
    assigns =
      assigns
      |> Keyword.put(:js, "role_form")
      |> Keyword.put(:notice, get_flash(conn, :notice))
      |> Keyword.put(:alert, get_flash(conn, :alert))

    render(conn, "show.html", assigns)
  end

  defp authorize_feature(conn, _opts) do
    case feature_state(conn) do
      :enabled -> conn
      :zero_state -> render_zero_state(conn)
      :hidden -> render_404(conn)
    end
  end

  defp feature_state(conn) do
    org_id = conn.assigns[:organization_id]
    feature_name = :rbac__custom_roles

    cond do
      FeatureProvider.feature_enabled?(feature_name, param: org_id) -> :enabled
      FeatureProvider.feature_zero_state?(feature_name, param: org_id) -> :zero_state
      true -> :hidden
    end
  end

  defp render_zero_state(conn) do
    conn
    |> render("zero_page.html", title: "Roles")
    |> Plug.Conn.halt()
  end

  defp render_404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end

  def audit_log(conn, action, role_id) when action in @audit_actions do
    conn
    |> Audit.new(:RBACRole, action)
    |> Audit.add(description: audit_desc(action))
    |> Audit.add(resource_id: role_id)
    |> Audit.log()
  end

  defp audit_desc(:Added), do: "Added RBAC role"
  defp audit_desc(:Modified), do: "Modified RBAC role"
  defp audit_desc(:Removed), do: "Removed RBAC role"

  defp log_data_closure(organization_id, user_id, action) do
    fn reason ->
      formatter = &"#{elem(&1, 0)}=\"#{inspect(elem(&1, 1))}\""

      %{
        organization_id: organization_id,
        requester_id: user_id,
        action: action,
        reason: reason
      }
      |> Enum.map_join(" ", formatter)
    end
  end

  defp watchman_name(method, metrics),
    do: "#{@watchman_prefix}.#{method}.#{metrics}"
end
