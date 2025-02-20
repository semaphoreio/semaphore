defmodule Audit.Streamer.FileFormatter do
  alias InternalApi.Audit.Event.{Medium, Resource, Operation}

  def csv(events) do
    events
    |> Enum.map(fn e ->
      %{
        "resource" => Resource.key(e.resource),
        "operation" => Operation.key(e.operation),
        "medium" => Medium.key(e.medium),
        "user_id" => e.user_id,
        "username" => e.username,
        "resource_id" => e.resource_id,
        "resource_name" => e.resource_name,
        "ip_address" => e.ip_address,
        "metadata" => Poison.encode!(e.metadata),
        "timestamp" => e.timestamp
      }
    end)
    |> CSV.encode(
      headers: [
        "resource",
        "operation",
        "medium",
        "user_id",
        "username",
        "resource_id",
        "resource_name",
        "ip_address",
        "metadata",
        "timestamp"
      ]
    )
    |> Enum.join()
  end
end
