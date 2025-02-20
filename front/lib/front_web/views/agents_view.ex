defmodule FrontWeb.AgentsView do
  use FrontWeb, :view

  def json_config(conn, activity) do
    %{
      baseUrl: agents_index_path(conn, :index, []),
      activity: activity,
      activityRefreshUrl: activity_monitor_path(conn, :activity_data),
      activityStopUrl: activity_monitor_path(conn, :stop),
      refreshPeriod: 5000,
      selfHostedUrl: self_hosted_agent_path(conn, :index),
      permissions:
        Map.take(conn.assigns.permissions, [
          "organization.view",
          "organization.self_hosted_agents.manage",
          "organization.self_hosted_agents.view",
          "organization.activity_monitor.view"
        ]),
      features: %{
        self_hosted_agents: feature_state(conn, :self_hosted_agents),
        expose_cloud_agent_types: feature_state(conn, :expose_cloud_agent_types)
      },
      docsDomain: Application.fetch_env!(:front, :docs_domain)
    }
    |> Poison.encode!()
  end

  @spec feature_state(Plug.Conn.t(), atom()) :: String.t()
  defp feature_state(conn, feature) do
    cond do
      FeatureProvider.feature_enabled?(feature, conn.assigns.organization_id) ->
        "enabled"

      FeatureProvider.feature_zero_state?(feature, conn.assigns.organization_id) ->
        "zero"

      true ->
        "disabled"
    end
  end
end
