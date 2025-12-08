defmodule Projecthub.Events.ProjectRestored do
  @exchange "project_exchange"
  @routing_key "restored"

  def publish(project, _opts \\ []) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    event =
      InternalApi.Projecthub.ProjectRestored.new(
        project_id: project.id,
        org_id: project.organization_id,
        timestamp: Google.Protobuf.Timestamp.new(seconds: timestamp)
      )

    message = InternalApi.Projecthub.ProjectRestored.encode(event)

    options = %{
      url: Application.fetch_env!(:projecthub, :amqp_url),
      exchange: @exchange,
      routing_key: @routing_key
    }

    Tackle.publish(message, options)

    {:ok, nil}
  end
end
