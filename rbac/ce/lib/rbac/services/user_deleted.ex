defmodule Rbac.Services.UserDeleted do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "user_exchange",
    routing_key: "deleted",
    service: "rbac.user_deleted"

  def handle_message(message) do
    Watchman.benchmark("user_deleted.duration", fn ->
      event = InternalApi.User.UserDeleted.decode(message)

      Logger.info("[UserDeleted] Processing: #{event.user_id}")

      Rbac.Models.RoleAssignment.delete_all_by_user_id(event.user_id)

      Logger.info("[UserDeleted] Processing finished. #{event.user_id}")
    end)
  end
end
