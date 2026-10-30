defmodule Projecthub.Events.ProjectRestored do
  @exchange "project_exchange"
  @routing_key "restored"
  @confirm_timeout {5, :second}
  @close_timeout_ms 2_000

  # Unlike Tackle.publish, every step is checked and the broker has to confirm the message,
  # because without this event a restored project's artifacts are still purged.
  def publish(project, _opts \\ []) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    event =
      InternalApi.Projecthub.ProjectRestored.new(
        project_id: project.id,
        org_id: project.organization_id,
        timestamp: Google.Protobuf.Timestamp.new(seconds: timestamp)
      )

    message = InternalApi.Projecthub.ProjectRestored.encode(event)

    {:ok, connection} = AMQP.Connection.open(Application.fetch_env!(:projecthub, :amqp_url))

    try do
      {:ok, channel} = AMQP.Channel.open(connection)
      :ok = AMQP.Exchange.direct(channel, @exchange, durable: true)
      :ok = AMQP.Confirm.select(channel)
      :ok = AMQP.Basic.publish(channel, @exchange, @routing_key, message, persistent: true)
      true = AMQP.Confirm.wait_for_confirms(channel, @confirm_timeout)
    after
      close(connection)
    end

    {:ok, nil}
  end

  # A broker that refuses writes does not answer a close either, so give up on it quickly.
  defp close(connection) do
    :amqp_connection.close(connection.pid, @close_timeout_ms)
  catch
    :exit, _ -> :ok
  end
end
