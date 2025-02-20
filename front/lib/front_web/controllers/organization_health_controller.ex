defmodule FrontWeb.OrganizationHealthController do
  use FrontWeb, :controller
  alias Front.Models
  alias FrontWeb.Plugs
  require Logger

  plug(
    Plugs.OrganizationAuthorization
    when action in [
           :index
         ]
  )

  plug(FrontWeb.Plugs.FeatureEnabled, [:organization_health])

  def index(conn, params) do
    ranges = Front.DateRangeGenerator.construct()

    date_range = Enum.fetch!(ranges, date_index(params))

    org_health = fetch_organization_health(conn, date_range)

    conn
    |> json(%{healths: org_health})
  end

  defp date_index(_params = %{"date_index" => date_index}) when is_binary(date_index),
    do: String.to_integer(date_index)

  defp date_index(params) when not is_map_key(params, :date_index), do: 0

  defp fetch_organization_health(conn, date_range) do
    user_id = conn.assigns.user_id
    org_id = conn.assigns.organization_id

    {:ok, project_ids} = Front.RBAC.Members.list_accessible_projects(org_id, user_id)

    list_org_health(project_ids, org_id, date_range)
    |> Enum.map(fn metric ->
      metric
      |> Map.put(:last_successful_run_at, Timex.from_unix(metric.last_successful_run_at.seconds))
      |> Map.put(:url, insights_index_path(conn, :index, metric.project_name, []))
    end)
  end

  defp list_org_health(project_ids, org_id, date_range) do
    case Models.OrganizationHealth.list(project_ids, org_id, date_range.from, date_range.to) do
      {:ok, response} ->
        response.health_metrics

      :error ->
        []
    end
  end
end
