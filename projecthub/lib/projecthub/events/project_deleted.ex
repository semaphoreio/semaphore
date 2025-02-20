defmodule Projecthub.Events.ProjectDeleted do
  def publish(project) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    event =
      InternalApi.Projecthub.ProjectDeleted.new(
        project_id: project.id,
        org_id: project.organization_id,
        timestamp: Google.Protobuf.Timestamp.new(seconds: timestamp)
      )

    message = InternalApi.Projecthub.ProjectDeleted.encode(event)

    options = %{
      url: Application.fetch_env!(:projecthub, :amqp_url),
      exchange: "project_exchange",
      routing_key: "deleted"
    }

    Tackle.publish(message, options)

    {:ok, nil}
  end
end
