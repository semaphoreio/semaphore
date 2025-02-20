defmodule FrontWeb.ActivityMonitorController do
  require Logger
  use FrontWeb, :controller
  alias Front.Audit

  if Application.compile_env(:front, :environment) == :dev do
    plug(FrontWeb.Plugs.Development.ActivityMonitor)
  end

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")

  plug(
    FrontWeb.Plugs.PageAccess,
    [permissions: "organization.activity_monitor.view"] when action == :activity_data
  )

  plug(FrontWeb.Plugs.Header when action in [:index])

  def index(conn, _params) do
    Watchman.benchmark("activity_monitor.index.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      user = Front.Models.User.find(user_id)
      activity = Front.ActivityMonitor.load(org_id, user_id)

      conn
      |> render("index.html",
        conn: conn,
        title: "Activity Monitor・Semaphore",
        activity: activity,
        permissions: conn.assigns.permissions,
        user_name: user.name,
        js: "activity_monitor",
        layout: {FrontWeb.LayoutView, "organization.html"}
      )
    end)
  end

  def activity_data(conn, _params) do
    Watchman.benchmark("activity_monitor.data.duration", fn ->
      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id

      tracing_headers = conn.assigns.tracing_headers

      activity = Front.ActivityMonitor.load(org_id, user_id, tracing_headers)

      conn |> json(activity)
    end)
  end

  def stop(conn, params) do
    Watchman.benchmark("activity_monitor.stop.duration", fn ->
      alias Front.ActivityMonitor.Actions

      user_id = conn.assigns.user_id
      org_id = conn.assigns.organization_id
      item_type = params["item_type"]
      item_id = params["item_id"]

      conn
      |> new_audit(item_type, item_id)
      |> Audit.log()

      case Actions.stop(org_id, user_id, item_type, item_id) do
        :ok ->
          conn |> put_status(:ok) |> json(%{message: "Stopped"})

        {:error, :bad_request, msg} ->
          conn |> put_status(:bad_request) |> json(%{message: msg})

        {:error, :forbidden, msg} ->
          conn |> put_status(:forbidden) |> json(%{message: msg})

        {:error, :not_found, msg} ->
          conn |> put_status(:not_found) |> json(%{message: msg})

        {:error, :unknown, msg} ->
          log_stop_error({org_id, user_id, item_type, item_id}, msg)
          conn |> put_status(:internal_server_error) |> json(%{message: msg})
      end
    end)
  end

  defp new_audit(conn, item_type, item_id) do
    cond do
      item_type == Front.ActivityMonitor.item_type_pipeline() ->
        conn
        |> Audit.new(:Pipeline, :Stopped)
        |> Audit.add(description: "Stopped a pipeline")
        |> Audit.add(resource_id: item_id)

      item_type == Front.ActivityMonitor.item_type_debug() ->
        conn
        |> Audit.new(:DebugSession, :Stopped)
        |> Audit.add(description: "Stopped a debug session")
        |> Audit.add(resource_id: item_id)

      true ->
        raise "unknown item type"
    end
  end

  defp log_stop_error({org_id, user_id, item_type, item_id}, msg) do
    "Stopping failed for (#{org_id}, #{user_id}, #{item_type}, #{item_id}, with #{msg}."
    |> Logger.error()
  end
end
