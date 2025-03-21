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

      disconnect_oidc_user(event.user_id)
      disconnect_okta_user(event.user_id)
      disconnect_saml_jit_user(event.user_id)

      Rbac.Store.RbacUser.delete(event.user_id)

      log(event.user_id, "Processing finished")
    end)
  end

  defp disconnect_oidc_user(user_id) do
    case Rbac.Store.OIDCUser.fetch_by_user_id(user_id) do
      {:ok, oidc_user} ->
        log(user_id, "OIDC user exists, deleting")

        Rbac.OIDC.User.delete_oidc_user(oidc_user.oidc_user_id)

      {:error, :not_found} ->
        log(user_id, "OIDC user does not exist, not syncing")
    end
  end

  defp disconnect_okta_user(user_id) do
    okta_users = Rbac.Repo.OktaUser.find_by_user_id(user_id)

    if Enum.empty?(okta_users) do
      log(user_id, "No Okta users found, not syncing")
    else
      log(user_id, "Found #{length(okta_users)} Okta users, disconnecting")

      Enum.each(okta_users, fn okta_user ->
        Rbac.Repo.OktaUser.disconnect_user(okta_user)
      end)
    end
  end

  defp disconnect_saml_jit_user(user_id) do
    saml_users = Rbac.Repo.SamlJitUser.find_by_user_id(user_id)

    if Enum.empty?(saml_users) do
      log(user_id, "No SAML JIT users found, not syncing")
    else
      log(user_id, "Found #{length(saml_users)} SAML JIT users, disconnecting")

      Enum.each(saml_users, fn saml_user ->
        Rbac.Repo.SamlJitUser.disconnect_user(saml_user)
      end)
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
