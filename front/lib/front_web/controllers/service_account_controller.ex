defmodule FrontWeb.ServiceAccountController do
  use FrontWeb, :controller
  require Logger

  alias Front.{Audit, Models}
  alias FrontWeb.Plugs.{FetchPermissions, PageAccess, FeatureEnabled}

  @manage ~w(create update delete regenerate_token)a

  plug(FetchPermissions, scope: "org")
  plug(PageAccess, permissions: "organization.service_accounts.view")
  plug(PageAccess, [permissions: "organization.service_accounts.manage"] when action in @manage)
  plug(FeatureEnabled, [:service_accounts])

  def index(conn, params) do
    org_id = conn.assigns.organization_id
    page = String.to_integer(params["page"] || "1")

    case Models.ServiceAccount.list(org_id, page) do
      {:ok, {service_accounts, total_pages}} ->
        conn
        |> render("index.json",
          service_accounts: service_accounts,
          total_pages: total_pages
        )

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
    role_id = params["role_id"] || ""

    Models.ServiceAccount.create(org_id, name, description, user_id, role_id)
    |> case do
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

  def update(conn, params = %{"id" => service_account_id}) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id
    name = params["name"] || ""
    description = params["description"] || ""
    role_id = params["role_id"] || ""

    Models.ServiceAccount.update(service_account_id, name, description, user_id, role_id)
    |> case do
      {:ok, service_account} ->
        conn
        |> Audit.new(:ServiceAccount, :Modified)
        |> Audit.add(resource_id: service_account.id)
        |> Audit.add(resource_name: service_account.name)
        |> Audit.add(description: "Service account updated")
        |> Audit.metadata(organization_id: org_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        render(conn, "show.json", service_account: service_account)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def delete(conn, %{"id" => service_account_id}) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id

    Models.ServiceAccount.delete(service_account_id)
    |> case do
      {:ok, service_account} ->
        conn
        |> Audit.new(:ServiceAccount, :Removed)
        |> Audit.add(resource_id: service_account.id)
        |> Audit.add(resource_name: service_account.name)
        |> Audit.add(description: "Service account deleted")
        |> Audit.metadata(organization_id: org_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        send_resp(conn, :no_content, "")

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def regenerate_token(conn, %{"id" => service_account_id}) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id

    Models.ServiceAccount.regenerate_token(service_account_id)
    |> case do
      {:ok, {service_account, api_token}} ->
        conn
        |> Audit.new(:ServiceAccount, :Rebuild)
        |> Audit.add(resource_id: service_account.id)
        |> Audit.add(resource_name: service_account.name)
        |> Audit.add(description: "Service account token regenerated")
        |> Audit.metadata(organization_id: org_id)
        |> Audit.metadata(user_id: user_id)
        |> Audit.log()

        json(conn, %{api_token: api_token})

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end
end
