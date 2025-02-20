defmodule Audit.Consumer do
  use Tackle.Consumer,
    url: Application.get_env(:audit, :amqp_url),
    service: "audit",
    exchange: "audit",
    routing_key: "log"

  def handle_message(message) do
    Watchman.benchmark("consumer.process.duration", fn ->
      event = InternalApi.Audit.Event.decode(message)

      if FeatureProvider.feature_enabled?(:audit_logs, event.org_id) do
        {:ok, _event} = process(event)
      end
    end)
  end

  @doc """
  Processes an event, it saves the event in the DB.
  """

  def process(event) do
    Watchman.increment({"consumer.events", [event.org_id]})

    {:ok, name} = find_user_name(event)

    Audit.Event.create(%{
      resource: InternalApi.Audit.Event.Resource.value(event.resource),
      operation: InternalApi.Audit.Event.Operation.value(event.operation),
      org_id: event.org_id,
      user_id: event.user_id,
      username: name,
      operation_id: event.operation_id,
      ip_address: event.ip_address,
      timestamp: DateTime.from_unix!(event.timestamp.seconds),
      resource_id: event.resource_id,
      resource_name: event.resource_name,
      description: event.description,
      metadata: Poison.decode!(event.metadata),
      medium: InternalApi.Audit.Event.Medium.value(event.medium)
    })
  end

  @doc """
  Finds the username associated with the user in the event.

  If the event contains a username, use it.
  Otherwise, look up the username from the User API.

  Publishing the username with the event is useful when the user is deleted.
  In other circumstances, finding the username can be a performance overhead.
  """
  def find_user_name(event) do
    if blank?(event.username) do
      Audit.User.name(event.user_id)
    else
      {:ok, event.username}
    end
  end

  def blank?(str), do: str == "" || str == nil
end
