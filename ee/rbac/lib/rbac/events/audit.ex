defmodule Rbac.Events.Audit do
  defstruct resource: nil,
            operation: nil,
            user_id: nil,
            username: "",
            org_id: nil,
            description: "",
            operation_id: nil,
            metadata: "{}",
            medium: nil

  def create_event(params) do
    struct(__MODULE__, params)
  end

  def publish(%__MODULE__{} = event) do
    message =
      %InternalApi.Audit.Event{
        resource: event.resource,
        operation: event.operation,
        user_id: event.user_id,
        username: event.username,
        org_id: event.org_id,
        description: event.description,
        operation_id: event.operation_id,
        metadata: event.metadata,
        medium: event.medium,
        timestamp: %Google.Protobuf.Timestamp{seconds: :os.system_time(:seconds)}
      }
      |> InternalApi.Audit.Event.encode()

    exchange_name = "audit"
    routing_key = "log"
    {:ok, channel} = AMQP.Application.get_channel(:authorization)
    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
  end
end
