defmodule Rbac.ProviderRefresher do
  require Logger

  @delay 1000
  def refresh(user_id) do
    Logger.info("Refreshing Providers for User: #{user_id}")
    Logger.info("Adding #{@delay} ms delay")
    :timer.sleep(@delay)

    user = Rbac.Store.User.Front.fetch_user_with_repo_account_details(user_id)

    outstream = map_providers(user.providers)
    current = Rbac.Store.User.fetch_providers(user_id)

    (current -- outstream) |> remove_providers(user_id)
    (outstream -- current) |> add_providers(user_id)

    Logger.info("End of Refreshing Providers for User: #{user_id}")
  end

  defp remove_providers(providers, user_id) do
    providers
    |> Enum.each(fn provider ->
      Rbac.Store.User.remove_provider(user_id, provider.type, provider.uid)
    end)
  end

  defp add_providers(providers, user_id) do
    providers
    |> Enum.each(fn provider ->
      Rbac.Store.User.remove_provider(provider.type, provider.uid)
      Rbac.Store.User.add_provider(user_id, provider.type, provider.uid)
    end)
  end

  defp map_providers(providers) do
    providers
    |> Enum.map(fn provider ->
      %{
        uid: provider["uid"],
        type: (provider["provider"] || "github") |> String.downcase()
      }
    end)
  end
end
