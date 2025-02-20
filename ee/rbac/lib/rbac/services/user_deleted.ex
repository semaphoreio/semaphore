defmodule Rbac.Services.UserDeleted do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "user_exchange",
    routing_key: "deleted",
    service: "guard.user_deleted"

  def handle_message(message) do
    Watchman.benchmark("user_deleted.duration", fn ->
      event = InternalApi.User.UserDeleted.decode(message)

      log(event.user_id, "Processing started")

      if Rbac.OIDC.enabled?() do
        handle_oidc_sync(event.user_id)
      end

      Rbac.Store.RbacUser.delete(event.user_id)

      log(event.user_id, "Processing finished")
    end)
  end

  defp handle_oidc_sync(user_id) do
    case Rbac.Store.OIDCUser.fetch_by_user_id(user_id) do
      {:ok, oidc_user} ->
        log(user_id, "OIDC user exists, deleting")

        Rbac.OIDC.User.delete_oidc_user(oidc_user.oidc_user_id)

      {:error, :not_found} ->
        log(user_id, "OIDC user does not exist, not syncing")
    end
  end

  defp log(level \\ :info, user_id, message) do
    message = "[User Deleted] #{user_id}: #{message}"

    case level do
      :info -> Logger.info(message)
      :error -> Logger.error(message)
    end
  end
end
