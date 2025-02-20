defmodule Rbac.Events.UserJoinedOrganization do
  alias Rbac.Store.Members

  def publish(members, org_id) when is_list(members) do
    members
    |> Enum.filter(fn m -> Members.count_memberships(m, org_id) == 1 end)
    |> Enum.map(fn m -> Members.extract_user_id(m) end)
    |> Enum.filter(fn m -> m end)
    |> Enum.each(fn user_id -> publish(user_id, org_id) end)

    :ok
  end

  def publish(user_id, org_id, join_time \\ DateTime.utc_now()) do
    event =
      %InternalApi.User.UserJoinedOrganization{
        user_id: user_id,
        org_id: org_id,
        timestamp: %Google.Protobuf.Timestamp{seconds: join_time |> DateTime.to_unix(:second)}
      }

    message = InternalApi.User.UserJoinedOrganization.encode(event)

    exchange_name = "user_exchange"
    routing_key = "user_joined_organization"
    {:ok, channel} = AMQP.Application.get_channel(:user)
    Tackle.Exchange.create(channel, exchange_name)
    :ok = Tackle.Exchange.publish(channel, exchange_name, message, routing_key)
  end
end
