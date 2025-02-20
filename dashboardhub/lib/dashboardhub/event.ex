defmodule Dashboardhub.Event do
  def publish(routing_key, dashboard_id, organization_id) do
    with :ok <- validate(routing_key) do
      date_time = DateTime.utc_now()

      event = %InternalApi.Dashboardhub.DashboardEvent{
        dashboard_id: dashboard_id,
        org_id: organization_id,
        timestamp: %Google.Protobuf.Timestamp{
          seconds: date_time |> seconds(),
          nanos: date_time |> nanos()
        }
      }

      event
      |> InternalApi.Dashboardhub.DashboardEvent.encode()
      |> Tackle.publish(%{
        url: Application.fetch_env!(:dashboardhub, :amqp_url),
        exchange: "dashboard_exchange",
        routing_key: routing_key
      })

      {:ok, nil}
    end
  end

  defp seconds(date_time) do
    date_time |> DateTime.to_unix(:second)
  end

  defp nanos(date_time) do
    elem(date_time.microsecond, 0) * 1_000
  end

  defp validate(routing_key) do
    case routing_key do
      "created" -> :ok
      "deleted" -> :ok
      "updated" -> :ok
      _ -> {:error, routing_key}
    end
  end
end
