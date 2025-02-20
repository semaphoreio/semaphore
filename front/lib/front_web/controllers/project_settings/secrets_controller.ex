# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.ProjectSettings.SecretsController do
  use FrontWeb, :controller
  require Logger

  alias Front.{Async, Audit}
  alias Front.Breadcrumbs.Project, as: Breadcrumbs
  alias Front.Form.SecretParamsHelper, as: Params
  alias Front.Models
  alias Front.Models.Secret

  plug(FrontWeb.Plugs.ProjectAuthorization when action not in [:index])
  plug(FrontWeb.Plugs.PutProjectAssigns when action in [:index])
  plug(FrontWeb.Plugs.FetchPermissions, [scope: "project"] when action in [:index])
  plug(FrontWeb.Plugs.PageAccess, [permissions: "project.view"] when action in [:index])
  plug(FrontWeb.Plugs.Header)
  plug(FrontWeb.Plugs.CacheControl, :no_cache)
  plug(:put_layout, :project_settings)
  plug(:authorize_feature)

  @watchman_prefix "project_secrets.endpoint"

  def index(conn, _params) do
    Watchman.benchmark(watchman_name(:index, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      project_id = conn.assigns.project.id || ""

      maybe_org_secrets =
        Async.run(fn ->
          Models.Secret.list_secrets(
            %{
              metadata: %{org_id: org_id, user_id: user_id},
              project_id: project_id,
              secret_level: :ORGANIZATION,
              ignore_contents: false
            },
            ""
          )
        end)

      maybe_project_secrets =
        Async.run(fn ->
          Secret.list(user_id, org_id, project_id, :PROJECT)
        end)

      fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

      with {:ok, org_data} <- Async.await(fetch_org),
           {:ok, {org_secrets, next_page_token}} <- Async.await(maybe_org_secrets),
           {:ok, project_secrets} <- Async.await(maybe_project_secrets) do
        render_page(
          conn,
          "index.html",
          %{
            project_secrets: project_secrets,
            org_secrets: %{
              secrets: org_secrets,
              next_page_url: next_page_url(next_page_token, conn.assigns.project.name)
            }
          },
          %{
            permissions: conn.assigns.permissions,
            org_restricted: org_data.restricted
          }
        )
      else
        _ -> render_404(conn)
      end
    end)
  end

  def org_secrets(conn, params) do
    project_id = conn.assigns.project.id || ""

    {secrets, next_page_token} =
      Models.Secret.list_secrets(
        %{
          metadata: %{org_id: conn.assigns.organization_id, user_id: conn.assigns.user_id},
          project_id: project_id,
          secret_level: :ORGANIZATION,
          ignore_contents: false
        },
        Map.get(params, "next_page_token", "")
      )

    json(conn, %{
      secrets: secrets,
      next_page_url: next_page_url(next_page_token, conn.assigns.project.name)
    })
  end

  def new(conn, _params) do
    Watchman.benchmark(watchman_name(:new, :duration), fn ->
      org_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      project_id = conn.assigns.project.id

      maybe_permissions =
        Async.run(fn ->
          Front.Auth.is_authorized?(org_id, user_id, [
            %{name: :ManageProjectSecrets, project_id: project_id}
          ])
        end)

      maybe_organization = Async.run(fn -> fetch_org_data(org_id) end)

      with {:ok, permissions} <- Async.await(maybe_permissions),
           {:ok, organization} <- Async.await(maybe_organization) do
        render_page(conn, "new.html", Params.construct_empty_inputs(), %{
          errors: nil,
          permissions: permissions,
          org_restricted: organization.restricted
        })
      else
        _ -> render_404(conn)
      end
    end)
  end

  def create(conn, params) do
    Watchman.benchmark(watchman_name(:create, :duration), fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      project_id = conn.assigns.project.id

      audit =
        conn
        |> Audit.new(:Secret, :Added)
        |> Audit.add(description: "Added secret #{params["name"]} to the project #{project_id}")
        |> Audit.add(resource_name: params["name"])
        |> Audit.metadata(project_id: project_id)
        |> Audit.metadata(project_name: conn.assigns.project.name)
        |> Audit.log()

      with {:ok, secret} <-
             Models.Secret.create(
               params["name"],
               Params.parse_params(params),
               %{project_id: project_id},
               :PROJECT,
               user_id,
               org_id
             ) do
        audit
        |> Audit.add(:resource_id, secret.id)
        |> Audit.log()

        conn
        |> put_flash(:notice, "Secret created.")
        |> redirect(to: secrets_path(conn, :index, conn.params["name_or_id"]))
      else
        {:error, validation_errors} ->
          maybe_permissions =
            Async.run(fn ->
              Front.Auth.is_authorized?(org_id, user_id, [
                %{name: :ManageProjectSecrets, project_id: project_id},
                %{name: :ViewSecrets}
              ])
            end)

          maybe_organization = Async.run(fn -> fetch_org_data(org_id) end)

          secret =
            params
            |> Params.parse_params()
            |> Models.Secret.construct_from_form_input(
              %{},
              params["name"]
            )
            |> Models.Secret.serialize_for_frontend()

          with {:ok, permissions} <- Async.await(maybe_permissions),
               {:ok, organization} <- Async.await(maybe_organization) do
            conn
            |> put_flash(:alert, compose_alert_message(validation_errors))
            |> put_status(422)
            |> render_page("new.html", secret, %{
              errors: validation_errors,
              permissions: permissions,
              org_restricted: organization.restricted
            })
          else
            _ -> render_404(conn)
          end

        error ->
          Logger.error("Error creating secret: #{inspect(error)}")
          render_404(conn)
      end
    end)
  end

  def edit(conn, params) do
    Watchman.benchmark(watchman_name(:edit, :duration), fn ->
      id = params["id"]
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      project = conn.assigns.project

      maybe_permissions =
        Async.run(fn ->
          Front.Auth.is_authorized?(org_id, user_id, [
            %{name: :ManageProjectSecrets, project_id: project.id}
          ])
        end)

      maybe_organization = Async.run(fn -> fetch_org_data(org_id) end)

      fetch_secret =
        Async.run(fn ->
          Models.Secret.find(id, user_id, org_id, secret_level: :PROJECT, project_id: project.id)
        end)

      with {:ok, permissions} <- Async.await(maybe_permissions),
           {:ok, organization} <- Async.await(maybe_organization),
           {:ok, {:ok, secret}} <- Async.await(fetch_secret) do
        render_page(conn, "edit.html", Models.Secret.serialize_for_frontend(secret), %{
          errors: nil,
          permissions: permissions,
          org_restricted: organization.restricted
        })
      else
        err ->
          Logger.error("Error editing secret: #{inspect(err)}")
          render_404(conn)
      end
    end)
  end

  def update(conn, params) do
    Watchman.benchmark(watchman_name(:update, :duration), fn ->
      secret_id = params["id"]
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      project = conn.assigns.project

      with {:ok, _secret} <-
             Models.Secret.update(
               secret_id,
               params["name"],
               params["description"],
               Params.parse_env_vars(params),
               Params.parse_files(params),
               user_id,
               org_id,
               secret_level: :PROJECT,
               project_config: %{project_id: project.id},
               project_id: project.id
             ) do
        conn
        |> Audit.new(:Secret, :Modified)
        |> Audit.add(description: "Updated secret #{params["name"]} in the project #{project.id}")
        |> Audit.add(resource_name: params["name"])
        |> Audit.metadata(project_id: project.id)
        |> Audit.metadata(project_name: project.name)
        |> Audit.log()

        conn
        |> put_flash(:notice, "Secret updated.")
        |> redirect(to: secrets_path(conn, :index, project.name))
      else
        {:error, :not_found} ->
          conn
          |> render_404

        {:error, message} ->
          conn
          |> put_flash(:alert, compose_alert_message(message))
          |> redirect(to: secrets_path(conn, :edit, project.name, secret_id))
      end
    end)
  end

  def delete(conn, params) do
    Watchman.benchmark(watchman_name(:delete, :duration), fn ->
      id = params["id"]
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      project = conn.assigns.project

      maybe_secret =
        Async.run(fn ->
          Models.Secret.find(id, user_id, org_id, secret_level: :PROJECT, project_id: project.id)
        end)

      with {:ok, {:ok, _secret}} <- Async.await(maybe_secret),
           {:ok, _} <-
             Models.Secret.destroy(id, user_id, org_id,
               secret_level: :PROJECT,
               project_id: project.id
             ) do
        conn
        |> Audit.new(:Secret, :Removed)
        |> Audit.add(description: "Deleted secret #{id} in the project #{project.id}")
        |> Audit.add(resource_name: id)
        |> Audit.metadata(project_id: project.id)
        |> Audit.metadata(project_name: project.name)
        |> Audit.log()

        conn
        |> put_flash(:notice, "Secret deleted.")
        |> redirect(to: secrets_path(conn, :index, project.name))
      else
        {:ok, {:error, :not_found}} ->
          render_404(conn)

        {:error, err} ->
          Logger.error("Error deleting secret: #{inspect(err)}")

          conn
          |> put_flash(:alert, "Failed to delete secret.")
          |> redirect(to: secrets_path(conn, :index, project.name))
      end
    end)
  end

  defp render_page(conn, "index.html", secrets, resources) do
    render_project_page(conn, "index.html", resources,
      title: "Secrets・#{conn.assigns.project.name}",
      js: :project_secrets,
      secrets: secrets
    )
  end

  defp render_page(conn, "new.html", secret, resources) do
    render_project_page(conn, "new.html", resources,
      title: "New Secret・#{conn.assigns.project.name}",
      js: "secret",
      action: secrets_path(conn, :create, conn.assigns.project.name),
      secret: secret
    )
  end

  defp render_page(conn, "edit.html", secret, resources) do
    render_project_page(conn, "edit.html", resources,
      title: "Editing Secret #{secret.name}・#{conn.assigns.project.name}",
      js: "secret",
      action: secrets_path(conn, :update, conn.assigns.project.name, secret.id),
      secret: secret
    )
  end

  defp render_project_page(conn, template, resources, args) do
    default_args = %{
      organization: conn.assigns.layout_model.current_organization,
      project: conn.assigns.project,
      notice: get_flash(conn, :notice),
      alert: get_flash(conn, :alert)
    }

    final_args =
      default_args
      |> Breadcrumbs.construct(conn, :settings)
      |> Map.merge(Map.new(args))
      |> Map.merge(resources)
      |> put_layout_assigns(conn, conn.assigns.project)

    render(conn, template, final_args)
  end

  defp put_layout_assigns(assigns, conn, project) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    is_project_starred? =
      Front.Tracing.track(conn.assigns.trace_id, "check_if_project_is_starred", fn ->
        Watchman.benchmark("project_page_check_star", fn ->
          Front.Models.User.has_favorite(user_id, org_id, project.id)
        end)
      end)

    js = if Map.get(assigns, :js), do: assigns.js, else: :project_header

    assigns
    |> Map.put(:starred?, is_project_starred?)
    |> Map.put(:js, js)
  end

  defp authorize_feature(conn, _opts) do
    enabled? =
      FeatureProvider.feature_enabled?(:project_level_secrets, conn.assigns.organization_id)

    if enabled?, do: conn, else: render_old_secrets_page(conn)
  end

  defp fetch_org_data(org_id) do
    case Front.Models.Organization.find(org_id, [:restricted], false) do
      nil -> %{restricted: false}
      org -> %{restricted: org.restricted}
    end
  end

  defp render_404(conn) do
    conn
    |> FrontWeb.PageController.status404(%{})
    |> Plug.Conn.halt()
  end

  defp render_old_secrets_page(conn) do
    project = conn.assigns.project
    org_id = conn.assigns.organization_id

    fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

    {:ok, org_data} = Async.await(fetch_org)

    assigns =
      %{
        project: project,
        title: "Settings・#{project.name}",
        org_restricted: org_data.restricted,
        permissions: conn.assigns.permissions
      }
      |> put_layout_assigns(conn, project)
      |> Front.Breadcrumbs.Project.construct(conn, :settings)

    conn
    |> render(
      "_old_secrets_page.html",
      assigns
    )
    |> Plug.Conn.halt()
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

  def audit_log(conn, action, target_id) do
    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: audit_desc(action))
    |> Audit.add(resource_id: conn.assigns.project.id)
    |> Audit.metadata(requester_id: conn.assigns.user_id)
    |> Audit.metadata(target_id: target_id)
    |> Audit.log()
  end

  defp audit_desc(:create), do: "Created project level secret"
  defp audit_desc(:update), do: "Updated project level secret"
  defp audit_desc(:delete), do: "Deleted project level secret"

  defp next_page_url("", _project_name), do: ""

  defp next_page_url(next_page_token, project_name),
    do: "/projects/#{project_name}/settings/secrets.json?next_page_token=#{next_page_token}"

  #
  # Watchman callbacks
  #
  defp watchman_name(method, metrics), do: "#{@watchman_prefix}.#{method}.#{metrics}"
end
