defmodule Rbac.Services.UserCreator do
  require Logger
  import Ecto.Query

  use Tackle.Consumer,
    url: Application.get_env(:rbac, :amqp_url),
    exchange: "user_exchange",
    routing_key: "created",
    service: "guard.user_creator"

  def handle_message(message) do
    Watchman.benchmark("user_creator.duration", fn ->
      event = InternalApi.User.UserCreated.decode(message)

      log(event.user_id, "Processing started")

      Rbac.ProviderRefresher.refresh(event.user_id)

      user =
        Rbac.FrontRepo.User |> where([user], user.id == ^event.user_id) |> Rbac.FrontRepo.one()

      rbac_user = Rbac.Store.RbacUser.fetch(user.id)

      if rbac_user == nil do
        log(event.user_id, "Syncing new user with rbac")

        GenRetry.retry(
          fn ->
            Rbac.Store.RbacUser.create(event.user_id, user.email, user.name)

            # It is possible that user has a member role inside some org, even though he was just created
            Rbac.TempSync.sync_new_user_with_members_table(event.user_id)
          end,
          retries: 10,
          delay: 1000
        )
      else
        log(event.user_id, "Rbac user already exists, not syncing")
      end

      log(event.user_id, "Processing finished")
    end)
  end

  defp log(level \\ :info, user_id, message) do
    message = "[User Creator] #{user_id}: #{message}"

    case level do
      :info -> Logger.info(message)
      :error -> Logger.error(message)
    end
  end
end
