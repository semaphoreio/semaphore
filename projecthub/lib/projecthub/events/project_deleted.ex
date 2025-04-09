defmodule Projecthub.Events.ProjectDeleted do
  @soft_deleted_routing_key "soft_deleted"
  @deleted_routing_key "deleted"

  def publish(project, opts \\ []) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    event =
      InternalApi.Projecthub.ProjectDeleted.new(
        project_id: project.id,
        org_id: project.organization_id,
        timestamp: Google.Protobuf.Timestamp.new(seconds: timestamp)
      )

    message = InternalApi.Projecthub.ProjectDeleted.encode(event)
    routing_key = if opts[:soft_delete], do: @soft_deleted_routing_key, else: @deleted_routing_key

    options = %{
      url: Application.fetch_env!(:projecthub, :amqp_url),
      exchange: "project_exchange",
      routing_key: routing_key
    }

    Tackle.publish(message, options)

    {:ok, nil}
  end
end
