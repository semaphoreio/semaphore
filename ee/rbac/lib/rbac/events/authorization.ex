defmodule Rbac.Events.Authorization do
  @exchange_name "rbac_exchange"
  # This event is emitted whenever there is some authorization change in the Rbac
  #
  # Mandatory parameters:
  #  - routing_key (Validated against and passed throught directly to Tackle)
  #  - user_id (The user for whom the authorization has changed)
  #  - org_id (The organization within authorization has changed)
  #
  # Optional:
  #  - project_id (Provide this parameter when authorization affects only one project)

  def publish(routing_key, user_id, org_id, project_id \\ "") do
    with :ok <- validate(routing_key) do
      date_time = DateTime.utc_now()

      event =
        %InternalApi.Guard.AuthorizationEvent{
          org_id: org_id,
          project_id: project_id,
          user_id: user_id,
          timestamp: %Google.Protobuf.Timestamp{
            seconds: date_time |> seconds(),
            nanos: date_time |> nanos()
          }
        }

      message = InternalApi.Guard.AuthorizationEvent.encode(event)

      {:ok, channel} = AMQP.Application.get_channel(:authorization)
      Tackle.Exchange.create(channel, @exchange_name)
      :ok = Tackle.Exchange.publish(channel, @exchange_name, message, routing_key)

      {:ok, message}
    end
  end

  defp validate(routing_key) do
    case routing_key do
      "collaborator_created" -> :ok
      "collaborator_deleted" -> :ok
      "role_created" -> :ok
      "role_deleted" -> :ok
      "role_assigned" -> :ok
      "role_retracted" -> :ok
      _ -> {:error, routing_key}
    end
  end

  defp seconds(date_time) do
    date_time |> DateTime.to_unix(:second)
  end

  defp nanos(date_time) do
    elem(date_time.microsecond, 0) * 1_000
  end
end
