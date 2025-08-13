defmodule FrontWeb.OrganizationContactsController do
  @moduledoc false
  use FrontWeb, :controller
  alias Front.Models.OrganizationContacts
  require Logger

  plug(FrontWeb.Plugs.OnPremBlocker)

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")

  plug(
    FrontWeb.Plugs.PageAccess,
    [permissions: "organization.general_settings.manage"] when action == :modify
  )

  plug(FrontWeb.Plugs.Header)
  plug(:put_layout, :organization_settings)

  @watchman_prefix "organization_contacts.endpoint"

  def show(conn, _params) do
    Watchman.benchmark(watchman_name(:show, :duration), fn ->
      org_id = conn.assigns.organization_id

      case OrganizationContacts.get_all(org_id) do
        {:ok, map_of_contact_changesets} ->
          Watchman.increment(watchman_name(:show, :success))

          render(
            conn,
            "show.html",
            title: "Contacts",
            permissions: conn.assigns.permissions,
            map_of_contact_changesets: map_of_contact_changesets,
            notice: get_flash(conn, :notice),
            alert: get_flash(conn, :alert)
          )

        _ ->
          Logger.error("Error while fetching contacts for organziation #{inspect(org_id)}")

          conn
          |> put_flash(
            :alert,
            "Error while fetching contacts. Please contact our support team."
          )
          |> redirect(to: settings_path(conn, :show))
      end
    end)
  end

  def modify(conn, %{"organization_contacts" => contact}) do
    Watchman.benchmark(watchman_name(:create, :duration), fn ->
      org_id = conn.assigns.organization_id

      contact = Map.put(contact, "org_id", org_id)

      case OrganizationContacts.modify(contact) do
        {:ok, _resp} ->
          conn
          |> put_flash(:notice, "Contact information successfully updated.")
          |> redirect(to: organization_contacts_path(conn, :show))

        _ ->
          conn
          |> put_flash(
            :alert,
            "Error while updating contact information. Please contact our support team."
          )
          |> redirect(to: organization_contacts_path(conn, :show))
      end
    end)
  end

  #
  # Watchman callbacks
  #
  defp watchman_name(method, metrics), do: "#{@watchman_prefix}.#{method}.#{metrics}"
end
