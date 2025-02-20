defmodule Notifications.Api.InternalApi.Serialization do
  require Logger

  alias InternalApi.Notifications.Notification

  def serialize(notification) do
    Notification.new(
      name: notification.name,
      id: notification.id,
      org_id: notification.org_id,
      create_time: timestamp(notification.inserted_at),
      update_time: timestamp(notification.updated_at),
      rules: rules(notification.spec["rules"] || notification.spec.rules),
      status: status(notification)
    )
  end

  def rules(rules) do
    Notifications.Util.Transforms.decode_spec(
      rules || [],
      InternalApi.Notifications.Notification.Rule
    )
  end

  def status(_notification) do
    # TODO
    Notification.Status.new()
  end

  def timestamp(ecto_time) do
    ts_in_microseconds =
      ecto_time |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix(:microsecond)

    seconds = div(ts_in_microseconds, 1_000_000)
    nanos = rem(ts_in_microseconds, 1_000_000) * 1_000
    %Google.Protobuf.Timestamp{seconds: seconds, nanos: nanos}
  end
end
