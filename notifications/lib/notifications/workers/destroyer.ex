defmodule Notifications.Workers.Destroyer do
  @moduledoc """
  Listens for organization deleted events and deletes organization related
  notifications.
  """

  require Logger
  alias Notifications.Models.Notification

  use Tackle.Consumer,
    url: Application.get_env(:notifications, :amqp_url),
    exchange: "organization_exchange",
    routing_key: "deleted",
    service: "notifications.destroyer"

  @metric_name "notification_destroyer"
  @log_prefix "[notification_destroyer] "

  def handle_message(message) do
    Watchman.benchmark({@metric_name <> ".duration", ["organization"]}, fn ->
      event = InternalApi.Organization.OrganizationDeleted.decode(message)

      log("Processing: #{event.org_id}")

      {num_of_deleted_notifications, _} =
        try do
          Notification
          |> Notification.in_org(event.org_id)
          |> Notifications.Repo.delete_all()
        rescue
          e ->
            Watchman.increment({@metric_name, ["error"]})
            Logger.error(@log_prefix <> "#{inspect(e)}")
            reraise e, __STACKTRACE__
        end

      log(
        "Deleted #{num_of_deleted_notifications} notifications for organization: #{event.org_id}"
      )
    end)
  end

  defp log(message), do: Logger.info(@log_prefix <> message)
end
