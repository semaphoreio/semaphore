defmodule FrontWeb.SettingsController do
  use FrontWeb, :controller

  alias Front.Async
  alias Front.Audit
  alias Front.Models

  require Logger

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")
  plug(FrontWeb.Plugs.Header when action not in [:update, :destroy])
  plug(:put_layout, :organization_settings)
  plug(FrontWeb.Plugs.CacheControl, :no_cache)

  def show(conn, _params) do
    Watchman.benchmark("settings.show.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)
      fetch_user = Async.run(fn -> Models.User.find(user_id) end)

      notice = conn |> get_flash(:notice)
      alert = conn |> get_flash(:alert)
      errors = conn |> get_flash(:errors) |> decode

      {:ok, user} = Async.await(fetch_user)
      {:ok, organization} = Async.await(fetch_organization)

      render(
        conn,
        "show.html",
        organization: organization,
        org_restricted: organization.restricted,
        user: user,
        errors: errors,
        notice: notice,
        alert: alert,
        permissions: conn.assigns.permissions,
        title: "Settings・#{organization.name}"
      )
    end)
  end

  def change_url(conn, _params) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)
    fetch_user = Async.run(fn -> Models.User.find(user_id) end)

    errors = conn |> get_flash(:errors) |> decode

    {:ok, user} = Async.await(fetch_user)
    {:ok, organization} = Async.await(fetch_organization)

    render(
      conn,
      "change_url.html",
      organization: organization,
      org_restricted: organization.restricted,
      user: user,
      errors: errors,
      permissions: conn.assigns.permissions,
      title: "#{organization.name} - Change URL"
    )
  end

  def ip_allow_list(conn, _params) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)
    fetch_user = Async.run(fn -> Models.User.find(user_id) end)

    errors = conn |> get_flash(:errors) |> decode

    {:ok, user} = Async.await(fetch_user)
    {:ok, organization} = Async.await(fetch_organization)

    render(
      conn,
      "ip_allow_list.html",
      organization: organization,
      user: user,
      errors: errors,
      permissions: conn.assigns.permissions,
      title: "IP Allow List・#{organization.name}"
    )
  end

  def confirm_enforce_workflow(conn, _params) do
    org_id = conn.assigns.organization_id
    permissions = conn.assigns.permissions || %{}

    if Map.get(permissions, "organization.general_settings.manage", false) do
      case Models.OrganizationSettings.modify(org_id, %{"enforce_whitelist" => "true"}) do
        {:ok, _updated_settings} ->
          conn
          |> put_flash(:notice, "Whitelist enforcement applied successfully.")
          |> redirect(to: settings_path(conn, :show))

        {:error, %Ecto.Changeset{} = changeset} ->
          errors =
            changeset.errors |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)

          conn
          |> put_flash(:errors, errors)
          |> put_flash(:alert, "Failed to apply whitelist enforcement.")
          |> redirect(to: settings_path(conn, :show))

        {:error, reason} ->
          conn
          |> put_flash(:errors, ["#{inspect(reason)}"])
          |> put_flash(:alert, "Failed to apply whitelist enforcement.")
          |> redirect(to: settings_path(conn, :show))
      end
    else
      conn
      |> put_flash(:alert, "Insufficient permissions.")
      |> redirect(to: settings_path(conn, :show))
    end
  end

  def confirm_delete(conn, _params) do
    org_id = conn.assigns.organization_id

    fetch_projects = Async.run(fn -> Models.Project.list_all(org_id) end)
    fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)

    errors = conn |> get_flash(:errors)
    alert = conn |> get_flash(:alert)

    {:ok, {:ok, projects}} = Async.await(fetch_projects)
    {:ok, org} = Async.await(fetch_organization)

    if Enum.empty?(projects) do
      render(
        conn,
        "confirm_delete.html",
        organization: org,
        org_restricted: org.restricted,
        errors: errors,
        alert: alert,
        can_delete: conn.assigns.permissions["organization.delete"] || false,
        title: "#{org.name} - Confirm delete"
      )
    else
      render(
        conn,
        "confirm_delete_non_deletable.html",
        organization: org,
        org_restricted: org.restricted,
        projects: projects,
        can_delete: conn.assigns.permissions["organization.delete"] || false,
        title: "#{org.name} - Confirm delete"
      )
    end
  end

  def update(conn, params) do
    Watchman.benchmark("settings.update.duration", fn ->
      org_id = conn.assigns.organization_id

      organization = Models.Organization.find(org_id)

      org_params = prepare_params_for_org_update(organization, params)

      conn
      |> Audit.new(:Organization, :Modified)
      |> Audit.add(:description, "Updating organization setting")
      |> Audit.metadata(org_params)
      |> Audit.log()

      needed_permission =
        if Map.has_key?(params, "ip_allow_list"),
          do: "organization.ip_allow_list.manage",
          else: "organization.general_settings.manage"

      redirect_path_suffix =
        if Map.has_key?(params, "ip_allow_list"), do: "ip_allow_list", else: ""

      if conn.assigns.permissions[needed_permission] || false do
        res = Models.Organization.update(organization, org_params)

        case res do
          {:ok, org} ->
            conn
            |> put_flash(:notice, "Changes saved.")
            |> redirect(external: updated_organization_settings_url(org, redirect_path_suffix))

          {:error, messages} ->
            conn
            |> put_flash(:errors, messages)
            |> put_flash(:alert, "Error updating organization settings: #{messages}")
            |> redirect(to: params["redirect_path"])
        end
      else
        conn
        |> put_flash(:alert, "Insufficient permissions.")
        |> redirect(
          external: updated_organization_settings_url(organization, redirect_path_suffix)
        )
      end
    end)
  end

  def destroy(conn, params) do
    org_id = conn.assigns.organization_id

    conn
    |> Audit.new(:Organization, :Removed)
    |> Audit.add(:description, "Deleting the organization")
    |> Audit.log()

    fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)
    fetch_project_count = Async.run(fn -> Models.Project.count(org_id) end)

    {:ok, organization} = Async.await(fetch_organization)
    {:ok, {:ok, project_count}} = Async.await(fetch_project_count)

    if conn.assigns.permissions["organization.delete"] || false do
      if project_count == 0 do
        if confirmed_delete?(params) do
          case Models.Organization.destroy(organization) do
            {:ok, _} ->
              domain = Application.get_env(:front, :domain)

              notice =
                "Organization #{organization.name} deleted." |> Poison.encode!(escape: :html_safe)

              Logger.info("Organization #{organization.name} deleted by #{conn.assigns.user_id}")

              conn
              |> redirect(external: "https://me.#{domain}/?notice=#{notice}")

            {:error, _} ->
              conn
              |> put_flash(:alert, "Failed to delete the organization.")
              |> redirect(to: settings_path(conn, :confirm_delete))
          end
        else
          conn
          |> put_flash(:errors, %{delete_account: "Incorrect confirmation"})
          |> redirect(to: settings_path(conn, :confirm_delete))
        end
      else
        conn
        |> put_flash(:alert, "Can't delete organization because there are active projects")
        |> redirect(to: settings_path(conn, :show))
      end
    else
      conn
      |> put_flash(:alert, "Insufficient permissions.")
      |> redirect(to: settings_path(conn, :show))
    end
  end

  defp confirmed_delete?(params) do
    params["delete_account"] == "delete"
  end

  defp prepare_params_for_org_update(org, params) do
    [
      name: params["name"] || org.name,
      username: params["username"] || org.username,
      deny_member_workflows: params["deny_member_workflows"] == "true",
      deny_non_member_workflows: params["deny_non_member_workflows"] == "true",
      ip_allow_list: prepare_ip_allow_list(params, org)
    ]
  end

  defp prepare_ip_allow_list(params, org) do
    if Map.has_key?(params, "ip_allow_list") do
      String.split(params["ip_allow_list"], ",", trim: true)
      |> Enum.map(fn s -> String.trim(s) end)
      |> Enum.filter(fn s -> s != "" end)
    else
      org.ip_allow_list
    end
  end

  defp updated_organization_settings_url(org, ""),
    do: "https://#{org.username}.#{Application.get_env(:front, :domain)}/settings"

  defp updated_organization_settings_url(org, suffix) do
    "https://#{org.username}.#{Application.get_env(:front, :domain)}/settings/#{suffix}"
  end

  defp decode(message) do
    if message do
      case Poison.decode(message) do
        {:ok, decoded} -> decoded
        {:error, _} -> ["Oops! Something went wrong."]
      end
    end
  end
end
