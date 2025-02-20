defmodule Rbac.Services.UserUpdater do
  require Logger

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "user_exchange",
    routing_key: "updated",
    service: "guard.user_updater"

  def handle_message(message) do
    Watchman.benchmark("user_updater.duration", fn ->
      event = InternalApi.User.UserUpdated.decode(message)

      log(event.user_id, "Processing started")

      Rbac.ProviderRefresher.refresh(event.user_id)

      # Syncing with RBAC
      # It is possible that user was added as a member to some organization via
      # this a new GH/BB account. When user connects their semaphore account with
      # the new GH/BB account, "user_update" event will be emitted, and we have to sync
      # with members and roles tables to see if that user should be assignem member role
      Rbac.TempSync.sync_new_user_with_members_table(event.user_id)

      # After that, we also need to see if the user is part of any project via this new GH/BB
      # account that was just connected to their Semaphore account
      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: event.user_id)
      Rbac.RoleManagement.assign_project_roles_to_repo_collaborators(rbi)

      if Rbac.OIDC.enabled?() do
        handle_oidc_sync(event.user_id)
      end

      log(event.user_id, "Processing finished")
    end)
  end

  defp handle_oidc_sync(user_id) do
    user = Rbac.Store.RbacUser.fetch(user_id)

    case Rbac.Store.OIDCUser.fetch_by_user_id(user_id) do
      {:ok, oidc_user} ->
        log(user_id, "OIDC user already exists, not syncing")

        case Rbac.OIDC.User.update_oidc_user(oidc_user.oidc_user_id, user) do
          {:ok, oidc_user_id} ->
            log(user_id, "OIDC user #{oidc_user_id} updated")

          e ->
            log(:error, user_id, "Error syncing new user with OIDC #{inspect(e)}")
        end

      {:error, :not_found} ->
        log(user_id, "Syncing new user with oidc")

        case Rbac.OIDC.User.create_oidc_user(user) do
          {:ok, oidc_user_id} ->
            log(user_id, "OIDC user #{oidc_user_id} created")

          e ->
            log(:error, user_id, "Error syncing new user with OIDC #{inspect(e)}")
        end
    end
  end

  defp log(level \\ :info, user_id, message) do
    message = "[User Updater] #{user_id}: #{message}"

    case level do
      :info -> Logger.info(message)
      :error -> Logger.error(message)
    end
  end
end
