defmodule FrontWeb.SecretsController do
  use FrontWeb, :controller

  alias Front.Form.SecretParamsHelper, as: Params

  alias Front.{
    Async,
    Audit,
    Models
  }

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")
  plug(FrontWeb.Plugs.Header when action in [:index, :edit, :new, :create])
  plug(:put_layout, :organization_settings)
  plug(FrontWeb.Plugs.CacheControl, :no_cache)

  def index(conn, params) do
    Watchman.benchmark("secrets.index.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)

      {:ok, organization} = Async.await(fetch_organization)

      next_page_token = Map.get(params, "next_page_token", "")

      {secrets, next_page_token} =
        Models.Secret.list_secrets(
          %{
            metadata: %{org_id: org_id, user_id: user_id},
            project_id: "",
            secret_level: :ORGANIZATION,
            ignore_contents: false
          },
          next_page_token
        )

      notice = conn |> get_flash(:notice)

      render(
        conn,
        "index.html",
        js: :organization_secrets,
        permissions: conn.assigns.permissions,
        secrets: secrets,
        next_page_url: next_page_url(next_page_token),
        organization: organization,
        title: "Secrets・#{organization.name}",
        notice: notice
      )
    end)
  end

  def secrets(conn, params) do
    {secrets, next_page_token} =
      Models.Secret.list_secrets(
        %{
          metadata: %{org_id: conn.assigns.organization_id, user_id: conn.assigns.user_id},
          project_id: "",
          secret_level: :ORGANIZATION,
          ignore_contents: false
        },
        Map.get(params, "next_page_token", "")
      )

    json(conn, %{
      secrets: secrets,
      next_page_url: next_page_url(next_page_token)
    })
  end

  def new(conn, _params) do
    Watchman.benchmark("secrets.new.duration", fn ->
      org_id = conn.assigns.organization_id

      fetch_projects = Async.run(fn -> Models.Project.list_all(org_id) end)
      organization = Models.Organization.find(org_id)

      notice = conn |> get_flash(:notice)
      alert = conn |> get_flash(:alert)

      {:ok, {:ok, projects}} = Async.await(fetch_projects)

      render(
        conn,
        "new.html",
        js: "secret",
        organization: organization,
        org_restricted: organization.restricted,
        notice: notice,
        secret: Params.construct_empty_inputs(),
        projects: projects,
        errors: nil,
        title: "New Secret・#{organization.name}",
        alert: alert,
        permissions: conn.assigns.permissions
      )
    end)
  end

  def create(conn, params) do
    Watchman.benchmark("secrets.create.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_projects = Async.run(fn -> Models.Project.list_all(org_id) end)

      audit =
        conn
        |> Audit.new(:Secret, :Added)
        |> Audit.add(description: "Added secret #{params["name"]} to the organization")
        |> Audit.add(resource_name: params["name"])
        |> Audit.log()

      {:ok, {:ok, projects}} = Async.await(fetch_projects)

      with true <- conn.assigns.permissions["organization.secrets.manage"],
           {:ok, secret} <-
             Models.Secret.create(
               params["name"],
               Params.parse_params(params),
               Params.parse_org_config(
                 params,
                 conn.assigns.permissions["organization.secrets_policy_settings.manage"]
               ),
               :ORGANIZATION,
               user_id,
               org_id
             ) do
        audit
        |> Audit.add(:resource_id, secret.id)
        |> Audit.log()

        conn
        |> put_flash(:notice, "Secret created.")
        |> redirect(to: secrets_path(conn, :index))
      else
        {:error, :permission_denied} ->
          conn
          |> render_404

        {:error, :not_found} ->
          conn
          |> render_404

        false ->
          conn
          |> put_flash(:alert, "You do not have permissions to create secrets.")
          |> redirect(to: secrets_path(conn, :index))

        {:error, validation_errors} ->
          organization = Models.Organization.find(org_id)

          secret =
            params
            |> Params.parse_env_vars_and_files()
            |> Models.Secret.construct_from_form_input(
              Params.parse_org_config(
                params,
                conn.assigns.permissions["organization.secrets_policy_settings.manage"]
              ),
              params["name"]
            )
            |> Models.Secret.serialize_for_frontend()

          assigns = %{
            errors: validation_errors,
            secret: secret,
            projects: projects,
            js: "secret",
            organization: organization,
            org_restricted: organization.restricted,
            title: "New Secret・#{organization.name}",
            permissions: conn.assigns.permissions
          }

          require Logger
          Logger.warn("validation errors: #{inspect(validation_errors)}")

          conn
          |> put_flash(:alert, compose_alert_message(validation_errors))
          |> put_status(422)
          |> render(
            "new.html",
            assigns
          )
      end
    end)
  end

  def update(conn, params) do
    Watchman.benchmark("secrets.update.duration", fn ->
      secret_id = params["id"]
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      conn
      |> Audit.new(:Secret, :Modified)
      |> Audit.add(description: "Modified #{params["name"]} secret")
      |> Audit.add(resource_name: params["name"])
      |> Audit.add(resource_id: secret_id)
      |> Audit.log()

      if conn.assigns.permissions["organization.secrets.manage"] || false do
        case Models.Secret.update(
               secret_id,
               params["name"],
               params["description"],
               Params.parse_env_vars(params),
               Params.parse_files(params),
               user_id,
               org_id,
               org_config:
                 Params.parse_org_config(
                   params,
                   conn.assigns.permissions["organization.secrets_policy_settings.manage"]
                 )
             ) do
          {:ok, _secret} ->
            conn
            |> put_flash(:notice, "Secret updated.")
            |> redirect(to: secrets_path(conn, :index))

          {:error, :not_found} ->
            conn
            |> render_404

          {:error, message} ->
            conn
            |> put_flash(:alert, compose_alert_message(message))
            |> redirect(to: secrets_path(conn, :edit, secret_id))
        end
      else
        conn
        |> put_flash(:notice, "Insufficient permissions.")
        |> redirect(to: secrets_path(conn, :index))
      end
    end)
  end

  def edit(conn, params) do
    Watchman.benchmark("secrets.edit.duration", fn ->
      id = params["id"]
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      fetch_secret = Async.run(fn -> Models.Secret.find(id, user_id, org_id) end)
      fetch_organization = Async.run(fn -> Models.Organization.find(org_id) end)
      fetch_projects = Async.run(fn -> Models.Project.list_all(org_id) end)

      {:ok, organization} = Async.await(fetch_organization)
      {:ok, secret_payload} = Async.await(fetch_secret)
      {:ok, projects_payload} = Async.await(fetch_projects)

      notice = conn |> get_flash(:notice)
      alert = conn |> get_flash(:alert)

      with {:ok, secret} <- secret_payload,
           {:ok, projects} <- projects_payload do
        render(
          conn,
          "edit.html",
          js: "secret",
          secret: Models.Secret.serialize_for_frontend(secret),
          projects: projects,
          organization: organization,
          org_restricted: organization.restricted,
          notice: notice,
          title: "Editing #{secret.name}・#{organization.name}",
          alert: alert,
          errors: nil,
          permissions: conn.assigns.permissions
        )
      else
        {:error, :not_found} ->
          render_404(conn)
      end
    end)
  end

  def log_remove_secret(conn, secret) do
    conn
    |> Audit.new(:Secret, :Removed)
    |> Audit.add(description: "Deleted #{secret.name} secret from the organization")
    |> Audit.add(resource_id: secret.id)
    |> Audit.log()
  end

  def delete(conn, params) do
    Watchman.benchmark("secrets.delete.duration", fn ->
      id = params["id"]
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      if conn.assigns.permissions["organization.secrets.manage"] || false do
        with {:ok, secret} <- Models.Secret.find(id, user_id, org_id),
             _ <- log_remove_secret(conn, secret),
             {:ok, _} <- Models.Secret.destroy(id, user_id, org_id) do
          conn
          |> put_flash(:notice, "Secret deleted.")
          |> redirect(to: secrets_path(conn, :index))
        else
          {:error, :not_found} ->
            conn |> render_404

          {:error, _} ->
            conn
            |> put_flash(:notice, "Failed to delete secret.")
            |> redirect(to: secrets_path(conn, :index))
        end
      else
        conn
        |> put_flash(:notice, "Insufficient permissions.")
        |> redirect(to: secrets_path(conn, :index))
      end
    end)
  end

  defp compose_alert_message(message) do
    case message do
      :grpc_req_failed ->
        # there was a grpc communication issues

        "Failed to create the secret. Please try again later."

      %{errors: %{other: m}} ->
        # Secrethub returned an unexpected validation error
        # This error isn't communicated within the form

        "Failed: #{m}"

      message when is_bitstring(message) ->
        # Secrethub had unknown error on update, show the message
        message

      _ ->
        # Secrethub returned an expected validation error
        # this error is communicated within the form

        "Failed to create the secret."
    end
  end

  defp next_page_url(""), do: ""

  defp next_page_url(next_page_token),
    do: "/secrets.json?next_page_token=#{next_page_token}"

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_layout(false)
    |> put_view(FrontWeb.ErrorView)
    |> render("404.html")
  end
end
