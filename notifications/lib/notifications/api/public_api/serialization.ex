defmodule Notifications.Api.PublicApi.Serialization do
  require Logger

  alias Semaphore.Notifications.V1alpha.Notification

  def serialize(notification) do
    Notification.new(
      metadata: metadata(notification),
      spec: spec(notification),
      status: status(notification)
    )
  end

  def metadata(notification) do
    Notification.Metadata.new(
      name: notification.name,
      id: notification.id,
      creator_id: notification.creator_id,
      create_time: unix_timestamp(notification.inserted_at),
      update_time: unix_timestamp(notification.updated_at)
    )
  end

  def spec(notification) do
    Notifications.Util.Transforms.decode_spec(
      notification.spec,
      Semaphore.Notifications.V1alpha.Notification.Spec
    )
  end

  def status(_notification) do
    # TODO
    Notification.Status.new()
  end

  def unix_timestamp(ecto_time) do
    ecto_time |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end
end
