defmodule FrontWeb.EphemeralEnvironmentController do
  use FrontWeb, :controller
  require Logger

  alias Front.Models
  alias FrontWeb.Plugs.{FetchPermissions, PageAccess, FeatureEnabled}

  @manage ~w(create delete cordon update)a

  plug(FetchPermissions, scope: "org")
  plug(PageAccess, permissions: "organization.ephemeral_environments.view")

  plug(
    PageAccess,
    [permissions: "organization.ephemeral_environments.manage"] when action in @manage
  )

  plug(FeatureEnabled, [:ephemeral_environments])

  # Apply conditional header for actions that might render HTML
  plug(:maybe_add_header when action in [:index, :show, :update])

  plug(:put_layout, :organization)

  # Page rendering action for the UI or API endpoint for listing
  def index(conn, params = %{"format" => "json"}) do
    org_id = conn.assigns.organization_id
    project_id = params["project_id"] || ""

    case Models.EphemeralEnvironment.list(org_id, project_id) do
      {:ok, environment_types} ->
        conn
        |> render("list.json", environment_types: environment_types)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def index(conn, _params) do
    render(conn, "index.html")
  end

  # API endpoint for listing environment types
  def list(conn, params) do
    org_id = conn.assigns.organization_id
    project_id = params["project_id"] || ""

    case Models.EphemeralEnvironment.list(org_id, project_id) do
      {:ok, environment_types} ->
        conn
        |> render("list.json", environment_types: environment_types)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def show(conn, %{"id" => environment_id, "format" => "json"}) do
    org_id = conn.assigns.organization_id

    case Models.EphemeralEnvironment.get(environment_id, org_id) do
      {:ok, environment_type} ->
        conn
        |> render("show.json", environment_type: environment_type)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def show(conn, _params) do
    render(conn, "index.html")
  end

  def create(conn, params) do
    org_id = conn.assigns.organization_id
    user_id = conn.assigns.user_id

    Models.EphemeralEnvironment.create(org_id, user_id, params)
    |> case do
      {:ok, environment_type} ->
        conn
        |> put_status(:created)
        |> render("show.json", environment_type: environment_type)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def delete(conn, %{"id" => environment_id}) do
    org_id = conn.assigns.organization_id

    Models.EphemeralEnvironment.delete(environment_id, org_id)
    |> case do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  def cordon(conn, %{"id" => environment_id}) do
    org_id = conn.assigns.organization_id

    Models.EphemeralEnvironment.cordon(environment_id, org_id)
    |> case do
      {:ok, environment_type} ->
        render(conn, "show.json", environment_type: environment_type)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end

  defp maybe_add_header(conn, _opts) do
    # Only add header if not requesting JSON
    if Map.get(conn.params, "format") != "json" do
      FrontWeb.Plugs.Header.call(conn, FrontWeb.Plugs.Header.init([]))
    else
      conn
    end
  end

  def update(conn, params = %{"id" => environment_id}) do
    org_id = conn.assigns.organization_id

    Models.EphemeralEnvironment.update(environment_id, org_id, params)
    |> case do
      {:ok, environment_type} ->
        conn
        |> render("show.json", environment_type: environment_type)

      {:error, message} ->
        conn
        |> put_status(422)
        |> json(%{error: message})
    end
  end
end
