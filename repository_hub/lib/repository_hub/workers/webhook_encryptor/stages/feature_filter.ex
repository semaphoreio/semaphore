defmodule RepositoryHub.WebhookEncryptor.FeatureFilter do
  @moduledoc """
  FeatureFilters filters out suspended organizations, and fetches organization username which is
  useful for regenerating Bitbucket webhooks.
  """

  use GenStage
  require Logger

  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:producer_consumer, args,
     subscribe_to: [
       {RepositoryHub.WebhookEncryptor.BroadcastProducer, max_demand: 10}
     ]}
  end

  def handle_events(messages, _from, state) do
    new_events =
      messages
      |> Stream.map(&process_message/1)
      |> Stream.reject(&match?({:error, _}, &1))
      |> Enum.into([], &elem(&1, 1))

    {:noreply, new_events, state}
  end

  @doc """
  Processes a Broadway message and filters whether
  organization should undergo webhook encryption.
  """
  def process_message(message) do
    alias InternalApi.Feature.OrganizationFeaturesChanged
    alias RepositoryHub.OrganizationClient

    event = OrganizationFeaturesChanged.decode(message.data)
    invalidate_cache(event)

    with {:ok, :feature_enabled} <- validate_feature(event.org_id),
         {:ok, response} <- OrganizationClient.describe(event.org_id),
         {:ok, organization} <- validate_suspension(response) do
      Logger.info(log(event, "⏩ Feature flag enabled, starting pipeline"))
      {:ok, %{org_id: event.org_id, org_username: organization.org_username}}
    else
      {:error, :feature_disabled} ->
        Logger.debug(log(event, "🖐🏻 Feature flag disabled, skipping organization"))
        {:error, :feature_disabled}

      {:error, :organization_suspended} ->
        Logger.debug(log(event, "🖐🏻 Organization suspended, skipping organization"))
        {:error, :organization_suspended}

      {:error, reason} ->
        Logger.error(log(event, "❌ Unable to fetch organization from API: #{inspect(reason)}"))
        {:error, reason}
    end
  end

  def invalidate_cache(event) do
    {_feature_provider, fp_opts} = Application.get_env(FeatureProvider, :provider)

    case Keyword.get(fp_opts, :cache) do
      {cache, cache_opts} ->
        cache.unset(event.org_id, cache_opts)
        Logger.debug(log(event, "ℹ️ Invalidated feature cache"))

      _ ->
        Logger.warning(log(event, "⛔️ Feature cache disabled"))
    end
  end

  defp validate_feature(_org_id) do
    {:ok, :feature_enabled}
  end

  defp validate_suspension(response = %{status: %{code: code}})
       when code == :OK or code == 0 do
    if response.organization.suspended,
      do: {:error, :organization_suspended},
      else: {:ok, response.organization}
  end

  defp validate_suspension(%{status: status} = _response) do
    {:error, {:grpc_error, status}}
  end

  defp log(event, message), do: "[WebhookEncryptor][FeatureFilter] {#{event.org_id}} #{message}"
end
