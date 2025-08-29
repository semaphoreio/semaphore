# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule FrontWeb.ProjectSettingsController do
  @moduledoc false
  require Logger
  use FrontWeb, :controller

  alias Front.{Async, Audit}
  alias FrontWeb.Plugs.{FeatureEnabled, FetchPermissions, Header, PageAccess, PutProjectAssigns}
  alias Front.Models.{Organization, Project, User}
  alias Front.ProjectSettings.DeletionValidator

  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")
  plug(PageAccess, permissions: "project.view")

  @edit_repo ~w(github_switch regenerate_webhook regenerate_deploy_key)a
  plug(PageAccess, [permissions: "project.repository_info.manage"] when action in @edit_repo)

  @edit_settings ~w(change_owner make_private make_public)a
  plug(PageAccess, [permissions: "project.general_settings.manage"] when action in @edit_settings)

  @delete_project ~w(submit_delete confirm_delete)a
  plug(PageAccess, [permissions: "project.delete"] when action in @delete_project)

  plug(PageAccess, [permissions: "project.access.manage"] when action == :update_debug_sessions)

  plug(
    PageAccess,
    [permissions: "project.artifacts.modify_settings"] when action == :update_artifact_settings
  )

  plug(
    FeatureEnabled,
    [:restrict_job_ssh_access] when action in [:permissions, :update_debug_sessions]
  )

  @header_actions ~w(
    general confirm_delete submit_delete update repository notifications workflow badge
    permissions update_debug_sessions change_owner update_artifact_settings artifacts
  )a
  plug(Header when action in @header_actions)

  plug(:put_layout, :project_settings)

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

  def github_switch(conn, _params) do
    Watchman.benchmark("project-settings.github_switch.duration", fn ->
      project = conn.assigns.project

      case Project.github_switch(project.id) do
        {:ok, _} ->
          conn
          |> put_flash(:notice, "Project connection type switched to GitHub app.")
          |> redirect(to: project_settings_path(conn, :repository, project.name))

        {:error, _} ->
          conn
          |> put_flash(
            :alert,
            "There was a problem with switching, please try again in a few minutes."
          )
          |> redirect(to: project_settings_path(conn, :repository, project.name))
      end
    end)
  end

  def repository(conn, _params) do
    Watchman.benchmark("project-settings.github.duration", fn ->
      alert = conn |> get_flash(:alert)
      notice = conn |> get_flash(:notice)

      project = conn.assigns.project
      changeset = Project.changeset(project)

      render_repository(conn, project, changeset, alert, notice)
    end)
  end

  def artifacts(conn, _params) do
    Watchman.benchmark("project-settings.artifacts.duration", fn ->
      render_artifacts_settings(conn)
    end)
  end

  def update_artifact_settings(conn, params) do
    Watchman.benchmark "project-settings.update_artifact_settings.duration" do
      project = conn.assigns.project
      form_data = params["artifact_settings"]

      audit_summary = Front.ProjectSettings.Artifacts.audit_summary(form_data)
      submit_audit_log(conn, project.id, project.name, audit_summary)

      case Front.ProjectSettings.Artifacts.update_settings(project.id, form_data) do
        {:ok, _policy} ->
          render_artifacts_settings(conn)

        err ->
          Logger.error("Failed to update retention policy #{inspect(err)}")

          conn
          |> put_flash(:info, "Failed to update retention policy")
          |> render_artifacts_settings()
      end
    end
  end

  defp render_artifacts_settings(conn) do
    org_id = conn.assigns.organization_id
    project = conn.assigns.project

    fetch_artifact_settings =
      Async.run(fn ->
        {:ok, policies} = Front.ProjectSettings.Artifacts.get_settings(project.id)
        policies
      end)

    fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

    {:ok, org_data} = Async.await(fetch_org)
    {:ok, artifact_retention_policies} = Async.await(fetch_artifact_settings)

    assigns =
      %{
        project: project,
        title: "Settings・#{project.name}",
        org_restricted: org_data.restricted,
        permissions: conn.assigns.permissions,
        js: :project_artifacts_settings,
        artifact_retention_policies: artifact_retention_policies,
        alert: get_flash(conn, :alert),
        notice: get_flash(conn, :notice)
      }
      |> put_layout_assigns(conn, project)
      |> Front.Breadcrumbs.Project.construct(conn, :settings)

    render(conn, "artifacts.html", assigns)
  end

  def notifications(conn, _params) do
    Watchman.benchmark("project-settings.notifications.duration", fn ->
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

      render(
        conn,
        "notifications.html",
        assigns
      )
    end)
  end

  def workflow(conn, _params) do
    Watchman.benchmark("project-settings.workflow.duration", fn ->
      project = conn.assigns.project
      org_id = conn.assigns.organization_id

      fetch_owner = Async.run(fn -> User.find(project.owner_id) end)
      fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

      {:ok, project_owner} = Async.await(fetch_owner)
      {:ok, org_data} = Async.await(fetch_org)

      assigns =
        %{
          project: project,
          project_owner: project_owner,
          title: "Settings・#{project.name}",
          org_restricted: org_data.restricted,
          permissions: conn.assigns.permissions
        }
        |> put_layout_assigns(conn, project)
        |> Front.Breadcrumbs.Project.construct(conn, :settings)

      render(
        conn,
        "workflow.html",
        assigns
      )
    end)
  end

  def badge(conn, _params) do
    Watchman.benchmark("project-settings.badge.duration", fn ->
      project = conn.assigns.project
      org_id = conn.assigns.organization_id

      fetch_org = Async.run(fn -> fetch_org_data(org_id) end)
      {:ok, org_data} = Async.await(fetch_org)

      assigns =
        %{
          organization_url:
            "https://#{org_data.username}.#{Application.get_env(:front, :domain)}",
          project: project,
          org_restricted: org_data.restricted,
          title: "Settings・#{project.name}",
          js: :badge_settings,
          permissions: conn.assigns.permissions
        }
        |> put_layout_assigns(conn, project)
        |> Front.Breadcrumbs.Project.construct(conn, :settings)

      render(
        conn,
        "badge.html",
        assigns
      )
    end)
  end

  def debug_sessions(conn, _),
    do: conn |> redirect(to: project_settings_path(conn, :permissions, conn.assigns.project.name))

  def permissions(conn, _params) do
    Watchman.benchmark("project-settings.permissions.duration", fn ->
      project = conn.assigns.project
      org_id = conn.assigns.organization_id
      changeset = Project.changeset(project)

      fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

      {:ok, org_data} = Async.await(fetch_org)

      case org_data.restricted do
        false ->
          conn
          |> render_404()

        true ->
          assigns =
            %{
              project: project,
              changeset: changeset,
              title: "Settings・#{project.name}",
              js: :debug_sessions_settings,
              org_restricted: org_data.restricted,
              permissions: conn.assigns.permissions
            }
            |> put_layout_assigns(conn, project)
            |> Front.Breadcrumbs.Project.construct(conn, :settings)

          render(
            conn,
            "permissions.html",
            assigns
          )
      end
    end)
  end

  def general(conn, _params) do
    Watchman.benchmark("project-settings.general.duration", fn ->
      alert = conn |> get_flash(:alert)
      notice = conn |> get_flash(:notice)

      project = conn.assigns.project
      changeset = Project.changeset(project)
      owner_changeset = Project.owner_changeset(project)

      render_general(conn, project, changeset, owner_changeset, alert, notice)
    end)
  end

  @doc """
  Form input requirements:
  - reason is always required
  - user needs to enter project name to confirm deletion
  - feedback is required if project is added in the last 7 days
  """
  def confirm_delete(conn, _params) do
    Watchman.benchmark("project-settings.confirm-deletion.duration", fn ->
      alert = conn |> get_flash(:alert)
      notice = conn |> get_flash(:notice)
      project = conn.assigns.project
      org_id = conn.assigns.organization_id

      fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

      {:ok, org_data} = Async.await(fetch_org)

      conn
      |> Audit.new(:Project, :Removed)
      |> Audit.add(description: "Removing a project")
      |> Audit.add(resource_id: project.id)
      |> Audit.add(resource_name: project.name)
      |> Audit.log()

      assigns =
        %{
          project: project,
          changeset: nil,
          notice: notice,
          alert: alert,
          title: "Delete Project・#{project.name}",
          org_restricted: org_data.restricted,
          permissions: conn.assigns.permissions
        }
        |> put_layout_assigns(conn, project)
        |> Front.Breadcrumbs.Project.construct(conn, :settings)

      render(
        conn,
        "confirm_delete.html",
        assigns
      )
    end)
  end

  def submit_delete(conn, params) do
    Watchman.benchmark("project-settings.submit-deletion.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      project = conn.assigns.project

      changeset = DeletionValidator.run(project, params)

      if Front.os?() or changeset.valid? do
        case Project.destroy(project.id, user_id, org_id) do
          {:ok, _} ->
            conn
            |> put_flash(:notice, "Project has been deleted.")
            |> redirect(to: dashboard_path(conn, :index))

          _ ->
            conn
            |> put_flash(:alert, "Failed to delete the project.")
            |> redirect(to: project_settings_path(conn, :general, project.name))
        end
      else
        fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

        {:ok, org_data} = Async.await(fetch_org)

        assigns =
          %{
            project: project,
            changeset: changeset,
            notice: nil,
            alert: nil,
            title: "Delete Project・#{project.name}",
            org_restricted: org_data.restricted,
            permissions: conn.assigns.permissions
          }
          |> put_layout_assigns(conn, project)
          |> Front.Breadcrumbs.Project.construct(conn, :settings)

        conn
        |> put_status(302)
        |> render(
          "confirm_delete.html",
          assigns
        )
      end
    end)
  end

  def update_debug_sessions(conn, params) do
    project = conn.assigns.project

    debug_params = params["project"] || %{}
    debug_description = Front.DebugSessionsDescription.description(debug_params)

    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: debug_description)
    |> Audit.add(resource_id: project.id)
    |> Audit.add(resource_name: project.name)
    |> Audit.log()

    update_project(
      conn,
      debug_params,
      "Project permissions have been updated.",
      :permissions
    )
  end

  def update(conn, %{"project" => %{"repo_url" => repo_url}}) do
    if conn.assigns.permissions["project.repository_info.manage"] do
      update_project(conn, %{repo_url: repo_url}, "Repository has been updated.", :repository)
    else
      render_404(conn)
    end
  end

  def update(conn, params) do
    if conn.assigns.permissions["project.general_settings.manage"] do
      update_project(conn, params["project"] || %{}, "Project has been updated.", :general)
    else
      render_404(conn)
    end
  end

  def make_public(conn, _params) do
    project = conn.assigns.project

    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: "Made project public.")
    |> Audit.add(resource_id: project.id)
    |> Audit.add(resource_name: project.name)
    |> Audit.log()

    update_project(conn, %{public: true}, "Project is now public on Semaphore.", :general)
  end

  def make_private(conn, _params) do
    project = conn.assigns.project

    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: "Made project private.")
    |> Audit.add(resource_id: project.id)
    |> Audit.add(resource_name: project.name)
    |> Audit.log()

    update_project(conn, %{public: false}, "Project is now private on Semaphore.", :general)
  end

  def change_owner(conn, params) do
    Watchman.benchmark("project-settings.change_owner.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      project = conn.assigns.project
      changeset = Project.owner_changeset(project, params["project"])

      conn
      |> Audit.new(:Project, :Modified)
      |> Audit.add(description: "Changed Project Owner.")
      |> Audit.add(resource_id: project.id)
      |> Audit.add(resource_name: project.name)
      |> Audit.metadata(new_owner_id: params["project"]["owner_id"])
      |> Audit.log()

      with {:ok, data} <- Ecto.Changeset.apply_action(changeset, :update),
           {:ok, _} <- Project.change_owner(org_id, project.id, data.owner_id, user_id) do
        conn
        |> put_flash(:notice, "Project Owner has been changed.")
        |> redirect(to: project_settings_path(conn, :general, project.name))
      else
        {:error, message} when is_binary(message) ->
          conn
          |> put_flash(:alert, URI.decode(message))
          |> redirect(to: project_settings_path(conn, :general, project.name))

        {:error, owner_changeset} ->
          alert = "Project Owner not changed."
          changeset = Project.changeset(project)

          render_general(conn, project, changeset, owner_changeset, alert, nil)
      end
    end)
  end

  def regenerate_deploy_key(conn, _params) do
    Watchman.benchmark("project-settings.regenerate_deploy_key.duration", fn ->
      project = conn.assigns.project

      case Project.regenerate_deploy_key(project.id) do
        {:ok, _key} ->
          conn
          |> put_flash(:notice, "Deploy Key has been regenerated.")
          |> redirect(to: project_settings_path(conn, :repository, project.name))

        {:error, message} ->
          conn
          |> put_flash(:alert, URI.decode(message))
          |> redirect(to: project_settings_path(conn, :repository, project.name))
      end
    end)
  end

  def regenerate_webhook(conn, _params) do
    Watchman.benchmark("project-settings.regenerate_webhook.duration", fn ->
      project = conn.assigns.project

      case Project.regenerate_webhook(project.id) do
        {:ok, _key} ->
          conn
          |> put_flash(:notice, "Webhook has been regenerated.")
          |> redirect(to: project_settings_path(conn, :repository, project.name))

        {:error, message} ->
          conn
          |> put_flash(:alert, URI.decode(message))
          |> redirect(to: project_settings_path(conn, :repository, project.name))
      end
    end)
  end

  defp update_project(conn, params, message, source) do
    Watchman.benchmark("project-settings.update.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      project = conn.assigns.project
      changeset = Project.changeset(project, params)

      with {:ok, project_data} <- Ecto.Changeset.apply_action(changeset, :update),
           {:ok, response} <- Project.update(project_data, user_id, org_id) do
        conn
        |> put_flash(:notice, message)
        |> redirect(to: project_settings_path(conn, source, response.project.metadata.name))
      else
        {:error, :message, ""} ->
          conn
          |> put_flash(:alert, "Failed to update.")
          |> redirect(to: project_settings_path(conn, source, project.name))

        {:error, :message, message} ->
          conn
          |> put_flash(:alert, URI.decode(message))
          |> redirect(to: project_settings_path(conn, source, project.name))

        {:error, :grpc_req_failed} ->
          Logger.error("Failed to update project: #{project.id} grpc_req_failed")

          conn
          |> put_flash(:alert, "Failed to update.")
          |> redirect(to: project_settings_path(conn, source, project.name))

        {:error, "non-authorized"} ->
          Logger.error("Failed to update project: #{project.id} non-authorized")

          conn
          |> put_flash(:alert, "Failed to update.")
          |> redirect(to: project_settings_path(conn, source, project.name))

        {:error, changeset} ->
          update_project_validation_error(source, conn, changeset)
      end
    end)
  end

  defp update_project_validation_error(:repository, conn, changeset) do
    project = conn.assigns.project
    alert = "Repository not updated."

    render_repository(conn, project, changeset, alert, nil)
  end

  defp update_project_validation_error(:general, conn, changeset) do
    project = conn.assigns.project
    alert = "Project not updated."
    owner_changeset = Project.owner_changeset(project)

    render_general(conn, project, changeset, owner_changeset, alert, nil)
  end

  defp render_repository(conn, project, changeset, alert, notice) do
    org_id = conn.assigns.organization_id

    fetch_project_owner = fetch_project_owner(project)
    fetch_token = fetch_token(project)
    fetch_github_installation = fetch_github_installation(project)
    fetch_deploy_key = fetch_deploy_key(project)
    fetch_webhook = fetch_webhook(project)
    fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

    {:ok, org_data} = Async.await(fetch_org)
    {:ok, project_owner} = Async.await(fetch_project_owner)
    {:ok, token} = Async.await(fetch_token)
    {:ok, github_installation} = Async.await(fetch_github_installation)
    {:ok, {key, key_message}} = Async.await(fetch_deploy_key)
    {:ok, {hook, hook_message}} = Async.await(fetch_webhook)

    assigns =
      %{
        project: project,
        changeset: changeset,
        project_owner: project_owner,
        project_token: token,
        github_installation: github_installation,
        deploy_key: key,
        deploy_key_message: key_message,
        hook: hook,
        hook_message: hook_message,
        notice: notice,
        alert: alert,
        title: "Settings・#{project.name}",
        js: :general_project_settings,
        org_restricted: org_data.restricted,
        permissions: conn.assigns.permissions
      }
      |> put_layout_assigns(conn, project)
      |> Front.Breadcrumbs.Project.construct(conn, :settings)

    render(
      conn,
      "repository.html",
      assigns
    )
  end

  defp render_general(conn, project, changeset, owner_changeset, alert, notice) do
    org_id = conn.assigns.organization_id

    fetch_project_owner = fetch_project_owner(project)
    fetch_token = fetch_token(project)
    fetch_org = Async.run(fn -> fetch_org_data(org_id) end)

    {:ok, org_data} = Async.await(fetch_org)
    {:ok, project_owner} = Async.await(fetch_project_owner)
    {:ok, token} = Async.await(fetch_token)

    assigns =
      %{
        project: project,
        project_owner: project_owner,
        project_token: token,
        changeset: changeset,
        owner_changeset: owner_changeset,
        notice: notice,
        alert: alert,
        title: "Settings・#{project.name}",
        js: :general_project_settings,
        org_restricted: org_data.restricted,
        permissions: conn.assigns.permissions
      }
      |> put_layout_assigns(conn, project)
      |> Front.Breadcrumbs.Project.construct(conn, :settings)

    render(
      conn,
      "general.html",
      assigns
    )
  end

  defp submit_audit_log(conn, project_id, project_name, summary) do
    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: "Changed artifact retention policy #{summary}")
    |> Audit.add(resource_id: project_id)
    |> Audit.add(resource_name: project_name)
    |> Audit.log()
  end

  defp fetch_org_data(org_id) do
    case Organization.find(org_id, [:username, :restricted]) do
      nil -> %{restricted: false, username: ""}
      org -> %{restricted: org.restricted, username: org.username}
    end
  end

  defp fetch_project_owner(project) do
    Async.run(fn -> User.find(project.owner_id) end)
  end

  defp fetch_token(project) do
    Async.run(fn ->
      case Project.check_token(project.id) do
        {:ok, token} -> token
        {:error, _} -> nil
      end
    end)
  end

  defp fetch_github_installation(project) do
    Async.run(fn ->
      case Project.github_installation_info(project.id) do
        {:ok, installation_info} -> installation_info
        {:error, _} -> nil
      end
    end)
  end

  defp fetch_deploy_key(project) do
    Async.run(fn ->
      case Project.check_deploy_key(project.id) do
        {:ok, key} -> {key, ""}
        {:error, message} -> {nil, message}
      end
    end)
  end

  defp fetch_webhook(project) do
    Async.run(fn ->
      case Project.check_webhook(project.id) do
        {:ok, hook} -> {hook, ""}
        {:error, message} -> {nil, message}
      end
    end)
  end

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_layout(false)
    |> put_view(FrontWeb.ErrorView)
    |> render("404.html")
  end
end
