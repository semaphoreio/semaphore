defmodule Projecthub.Events.ProjectCreated do
  @spec publish(%{project_id: String.t(), organization_id: String.t()}) :: {:ok, nil}
  def publish(%{project_id: project_id, organization_id: organization_id}) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    event =
      InternalApi.Projecthub.ProjectCreated.new(
        project_id: project_id,
        org_id: organization_id,
        timestamp: Google.Protobuf.Timestamp.new(seconds: timestamp)
      )

    message = InternalApi.Projecthub.ProjectCreated.encode(event)

    options = %{
      url: Application.fetch_env!(:projecthub, :amqp_url),
      exchange: "project_exchange",
      routing_key: "created"
    }

    Tackle.publish(message, options)

    {:ok, nil}
  end
end
