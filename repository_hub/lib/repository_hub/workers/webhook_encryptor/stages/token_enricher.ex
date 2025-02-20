defmodule RepositoryHub.WebhookEncryptor.TokenEnricher do
  @moduledoc """
  Reduces project events to token aggregate events.

  Based on the integration type, it acquires a token for the event and adds it to the event.
  """

  use GenStage
  require Logger

  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  # GenStage callbacks

  def init(args) do
    {:producer_consumer, args,
     subscribe_to: [
       {RepositoryHub.WebhookEncryptor.ProjectSplitter, max_demand: 20}
     ]}
  end

  def handle_events(events, _from, state) do
    new_events =
      events
      |> Stream.map(&transform_event/1)
      |> Stream.reject(&match?({:error, _}, &1))
      |> Enum.into([], &elem(&1, 1))

    {:noreply, new_events, state}
  end

  def transform_event(event) do
    case acquire_token_for_event(event) do
      {:ok, token} ->
        Logger.info(log_message(event, "ℹ️ Acquired repository access token"))
        {:ok, Map.put(event, :token, token)}

      {:error, reason} ->
        Logger.info(log_message(event, "❌ Acquiring token failed: #{inspect(reason)}"))
        {:error, reason}
    end
  end

  defp acquire_token_for_event(%{integration_type: "github_oauth_token", project_owner_id: owner_id}),
    do: RepositoryHub.UserClient.get_repository_token("github_oauth_token", owner_id)

  defp acquire_token_for_event(%{integration_type: "github_app", git_repository: git_repo}),
    do: RepositoryHub.RepositoryIntegratorClient.get_token(1, "#{git_repo.owner}/#{git_repo.name}")

  defp acquire_token_for_event(%{integration_type: "bitbucket", project_owner_id: owner_id}),
    do: RepositoryHub.UserClient.get_repository_token("bitbucket", owner_id)

  defp log_message(event, message), do: "[WebhookEncryptor][TokenReducer] {#{event.project_id}} #{message}"
end
