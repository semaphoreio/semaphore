defmodule Rbac.Events do
  require Logger

  @exchange_name "rbac_exchange"
  @allowed_routing_keys ["role_assigned", "role_retracted"]
  # This event is emitted whenever there is some authorization change in the Rbac
  #
  # Mandatory parameters:
  #  - routing_key (Validated against and passed throught directly to Tackle)
  #  - user_id (The user for whom the authorization has changed)
  #  - org_id (The organization within authorization has changed)
  #
  # Optional:
  #  - project_id (Provide this parameter when authorization affects only one project)

  @spec publish(
          routing_key :: String.t(),
          user_id :: String.t(),
          org_id :: String.t(),
          project_id :: String.t()
        ) :: :ok | :error
  def publish(routing_key, user_id, org_id, project_id \\ "") do
    with :ok <- validate(routing_key),
         {:ok, channel} <- AMQP.Application.get_channel(:authorization),
         _ <- Tackle.Exchange.create(channel, @exchange_name),
         message <- encode_message(org_id, project_id, user_id),
         :ok <- Tackle.Exchange.publish(channel, @exchange_name, message, routing_key) do
      :ok
    else
      error ->
        Logger.error("Publishing message failed: #{inspect(error)}")

        :error
    end
  end

  defp encode_message(org_id, project_id, user_id) do
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

    InternalApi.Guard.AuthorizationEvent.encode(event)
  end

  defp validate(routing_key),
    do: if(routing_key in @allowed_routing_keys, do: :ok, else: :error)

  defp seconds(date_time) do
    date_time |> DateTime.to_unix(:second)
  end

  defp nanos(date_time) do
    elem(date_time.microsecond, 0) * 1_000
  end
end
