defmodule Dashboardhub.Events.DashboardDeleted do
  alias Dashboardhub.Events.Publisher

  def publish(dashboard) do
    %InternalApi.Dashboardhub.DashboardEvent{
      dashboard_id: dashboard.id,
      org_id: dashboard.org_id,
      timestamp: %Google.Protobuf.Timestamp{seconds: DateTime.utc_now() |> DateTime.to_unix()}
    }
    |> InternalApi.Dashboardhub.DashboardEvent.encode()
    |> Publisher.publish(%{routing_key: "deleted", channel: :dashboardhub})

    {:ok, nil}
  end
end
