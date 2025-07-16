defmodule FrontWeb.ServiceAccountController do
  use FrontWeb, :controller
  require Logger

  alias Front.{Audit, ServiceAccount}
  alias FrontWeb.Plugs

  plug(Plugs.FetchPermissions, scope: "org")
  plug(Plugs.PageAccess, permissions: "organization.service_accounts.view")

  plug(
    Plugs.PageAccess,
    [permissions: "organization.service_accounts.manage"]
    when action in [:create, :update, :delete, :regenerate_token]
  )

  plug(Plugs.FeatureEnabled, [:service_accounts])

  def index(conn, params) do
    org_id = conn.assigns.organization_id
    page_size = String.to_integer(params["page_size"] || "20")
    page_token = params["page_token"]

    case ServiceAccount.list(org_id, page_size, page_token) do
      {:ok, {service_accounts, next_page_token}} ->
        conn
        |> put_resp_header("x-next-page-token", next_page_token || "")
        |> render("index.json", service_accounts: service_accounts)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def create(conn, params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    name = params["name"] || ""
    description = params["description"] || ""

    case ServiceAccount.create(org_id, name, description, user_id) do
      {:ok, {service_account, api_token}} ->
        conn
        |> Audit.new(:ServiceAccount, :Added)
        |> Audit.add(resource_id: service_account.id)
        |> Audit.add(resource_name: service_account.name)
        |> Audit.add(description: "Service account created")
        |> Audit.metadata(organization_id: org_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        conn
        |> put_status(:created)
        |> render("show.json", service_account: service_account, api_token: api_token)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def show(conn, %{"id" => id}) do
    case ServiceAccount.describe(id) do
      {:ok, service_account} ->
        render(conn, "show.json", service_account: service_account)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def update(conn, params = %{"id" => id}) do
    name = params["name"] || ""
    description = params["description"] || ""

    case ServiceAccount.update(id, name, description) do
      {:ok, service_account} ->
        conn
        |> Audit.new(:ServiceAccount, :Modified)
        |> Audit.add(resource_id: service_account.id)
        |> Audit.add(resource_name: service_account.name)
        |> Audit.add(description: "Service account updated")
        |> Audit.metadata(organization_id: conn.assigns.organization_id)
        |> Audit.metadata(user_id: conn.assigns.user_id)
        |> Audit.log()

        render(conn, "show.json", service_account: service_account)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def delete(conn, %{"id" => id}) do
    with {:ok, existing} <- ServiceAccount.describe(id),
         :ok <- ServiceAccount.delete(id) do
      conn
      |> Audit.new(:ServiceAccount, :Removed)
      |> Audit.add(resource_id: id)
      |> Audit.add(resource_name: existing.name)
      |> Audit.add(description: "Service account deleted")
      |> Audit.metadata(organization_id: conn.assigns.organization_id)
      |> Audit.metadata(user_id: conn.assigns.user_id)
      |> Audit.log()

      send_resp(conn, :no_content, "")
    else
      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def regenerate_token(conn, %{"id" => id}) do
    with {:ok, existing} <- ServiceAccount.describe(id),
         {:ok, api_token} <- ServiceAccount.regenerate_token(id) do
      conn
      |> Audit.new(:ServiceAccount, :Rebuild)
      |> Audit.add(resource_id: id)
      |> Audit.add(resource_name: existing.name)
      |> Audit.add(description: "Service account token regenerated")
      |> Audit.metadata(organization_id: conn.assigns.organization_id)
      |> Audit.metadata(user_id: conn.assigns.user_id)
      |> Audit.log()

      json(conn, %{api_token: api_token})
    else
      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end
end
