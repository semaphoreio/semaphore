defmodule FrontWeb.ProjectPFCController do
  use FrontWeb, :controller
  alias Front.{Async, Audit}
  require Logger

  alias Front.Models.PreFlightChecks.ProjectPFC
  alias FrontWeb.Plugs.{FetchPermissions, Header, PageAccess, PutProjectAssigns}

  @modify ~w(put delete)a

  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")
  plug(PageAccess, permissions: "project.view")
  plug(PageAccess, [permissions: "project.pre_flight_checks.manage"] when action in @modify)
  plug(Header when action in [:show, :put, :delete])
  plug(:put_layout, :project_settings)

  @watchman_prefix "project_pfcs.endpoint"

  def show(conn, _params) do
    Watchman.benchmark(watchman_name(:show, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      project = conn.assigns.project
      project_id = project.id

      log_data = log_data_closure(organization_id, project_id, user_id, :show)
      maybe_model = Async.run(fetch_model(project_id))

      with {:ok, params} <- fetch_params(organization_id, user_id),
           {:ok, model} <- Async.await(maybe_model) do
        Watchman.increment(watchman_name(:show, :success))

        changeset = ProjectPFC.changeset(model)
        render_page(conn, changeset, params)
      else
        {:error, reason} ->
          Watchman.increment(watchman_name(:show, :failure))
          Logger.error(log_data.(reason))
          {:error, reason}
      end
    end)
  end

  def put(conn, %{"name_or_id" => project_name_or_id, "project_pfc" => pfc_params}) do
    Watchman.benchmark(watchman_name(:put, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      project = conn.assigns.project
      project_id = project.id

      log_data = log_data_closure(organization_id, project_id, user_id, :put)
      audit_log(conn)

      changeset = ProjectPFC.empty() |> ProjectPFC.changeset(pfc_params)

      with {:ok, params} <- fetch_params(organization_id, user_id),
           {:ok, conn} <- validate_and_apply(conn, project_name_or_id, changeset, params) do
        Watchman.increment(watchman_name(:put, :success))
        conn
      else
        {:error, reason} ->
          Watchman.increment(watchman_name(:put, :failure))
          Logger.error(log_data.(reason))

          conn
          |> put_flash(:alert, "Failure: Unable to configure pre-flight checks")
          |> redirect(to: project_pfc_path(conn, :show, project_name_or_id))
      end
    end)
  end

  defp validate_and_apply(conn, project_name_or_id, changeset, params) do
    organization_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id
    user_id = conn.assigns.user_id

    with {:ok, model} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, _model} <- ProjectPFC.apply(organization_id, project_id, user_id, model) do
      {:ok,
       conn
       |> put_flash(:notice, "Success: pre-flight checks configured")
       |> redirect(to: project_pfc_path(conn, :show, project_name_or_id))}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:ok,
         conn
         |> put_flash(:alert, "Failure: provided invalid data")
         |> render_page(changeset, params)}
    end
  end

  def delete(conn, %{"name_or_id" => project_name_or_id}) do
    Watchman.benchmark(watchman_name(:delete, :duration), fn ->
      organization_id = conn.assigns.organization_id
      user_id = conn.assigns.user_id
      project = conn.assigns.project
      project_id = project.id

      log_data = log_data_closure(organization_id, project_id, user_id, :delete)
      audit_log(conn)

      case ProjectPFC.destroy(project_id, user_id) do
        :ok ->
          Watchman.increment(watchman_name(:delete, :success))

          conn
          |> put_flash(:notice, "Success: pre-flight checks deleted")
          |> redirect(to: project_pfc_path(conn, :show, project_name_or_id))

        {:error, reason} ->
          Watchman.increment(watchman_name(:delete, :failure))
          Logger.error(log_data.(reason))

          conn
          |> put_flash(:alert, "Failure: cannot delete pre-flight checks")
          |> redirect(to: project_pfc_path(conn, :show, project_name_or_id))
      end
    end)
  end

  defp fetch_params(organization_id, user_id) do
    maybe_organization = Async.run(fetch_organization(organization_id))
    maybe_secrets = Async.run(fetch_secrets(organization_id, user_id))
    maybe_cloud_agents = Async.run(fetch_cloud_agents(organization_id))
    maybe_self_hosted_agents = Async.run(fetch_self_hosted_agents(organization_id))

    with {:ok, organization} <- Async.await(maybe_organization),
         {:ok, secrets} <- Async.await(maybe_secrets),
         {:ok, {:ok, cloud_agents}} <- Async.await(maybe_cloud_agents),
         {:ok, {:ok, self_hosted_agents}} <- Async.await(maybe_self_hosted_agents) do
      {:ok,
       %{
         organization: organization,
         secrets: secrets,
         cloud_agents: cloud_agents,
         self_hosted_agents: self_hosted_agents
       }}
    end
  end

  defp fetch_organization(organization_id),
    do: fn ->
      Front.Models.Organization.find(organization_id)
    end

  defp fetch_model(project_id),
    do: fn ->
      case ProjectPFC.describe(project_id) do
        {:ok, model} -> model
        {:error, %{code: :NOT_FOUND}} -> ProjectPFC.new()
        {:error, error} -> raise error
      end
    end

  defp fetch_secrets(organization_id, user_id),
    do: fn -> Front.Models.Secret.list(user_id, organization_id, "", :ORGANIZATION, true) end

  defp fetch_cloud_agents(organization_id),
    do: fn -> Front.Models.AgentType.list(organization_id) end

  defp fetch_self_hosted_agents(organization_id),
    do: fn -> Front.SelfHostedAgents.AgentType.list(organization_id) end

  defp render_page(conn, changeset, params) do
    assigns =
      %{
        project: conn.assigns.project,
        title: "Settings・#{conn.assigns.project.name}",
        org_restricted: params.organization.restricted,
        changeset: changeset,
        secrets: params.secrets,
        cloud_agents: params.cloud_agents,
        self_hosted_agents: params.self_hosted_agents,
        alert: get_flash(conn, :alert),
        notice: get_flash(conn, :notice),
        starred?: project_starred?(conn),
        js: :project_pfcs
      }
      |> Front.Breadcrumbs.Project.construct(conn, :settings)

    render(conn, "show.html", assigns)
  end

  defp project_starred?(conn) do
    organization_id = conn.assigns.organization_id
    project_id = conn.assigns.project.id
    user_id = conn.assigns.user_id

    Front.Tracing.track(conn.assigns.trace_id, "check_if_project_is_starred", fn ->
      Watchman.benchmark("project_page_check_star", fn ->
        Front.Models.User.has_favorite(user_id, organization_id, project_id)
      end)
    end)
  end

  defp log_data_closure(organization_id, project_id, user_id, action) do
    fn reason ->
      formatter = &"#{elem(&1, 0)}=\"#{inspect(elem(&1, 1))}\""

      %{
        organization_id: organization_id,
        project_id: project_id,
        requester_id: user_id,
        action: action,
        reason: reason
      }
      |> Enum.map_join(" ", formatter)
    end
  end

  defp audit_log(conn = %Plug.Conn{method: "PUT"}) do
    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: "Applied project pre-flight checks")
    |> Audit.add(resource_id: conn.assigns.project.id)
    |> Audit.metadata(requester_id: conn.assigns.user_id)
    |> Audit.log()
  end

  defp audit_log(conn = %Plug.Conn{method: "DELETE"}) do
    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: "Deleted project pre-flight checks")
    |> Audit.add(resource_id: conn.assigns.project.id)
    |> Audit.metadata(requester_id: conn.assigns.user_id)
    |> Audit.log()
  end

  #
  # Watchman callbacks
  #
  defp watchman_name(method, metrics), do: "#{@watchman_prefix}.#{method}.#{metrics}"
end
