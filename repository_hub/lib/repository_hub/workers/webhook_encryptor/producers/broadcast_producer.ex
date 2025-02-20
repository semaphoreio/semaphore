defmodule RepositoryHub.WebhookEncryptor.BroadcastProducer do
  @moduledoc """
  Broadcasts events for webhook encryption manually
  """
  use GenStage

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args) do
    GenStage.start_link(__MODULE__, args, name: __MODULE__)
  end

  @spec publish(org_id :: String.t()) :: :ok
  def publish(org_id) do
    GenStage.call(__MODULE__, {:publish, org_id})
  end

  @impl true
  def init(_args) do
    {:producer, %{}, dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl true
  def handle_call({:publish, org_id}, _from, state) do
    event = %InternalApi.Feature.OrganizationFeaturesChanged{
      org_id: org_id
    }

    enc_event = InternalApi.Feature.OrganizationFeaturesChanged.encode(event)
    message = %Broadway.Message{data: enc_event, acknowledger: Broadway.NoopAcknowledger.init()}
    {:reply, :ok, [message], state}
  end

  @impl true
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end
end
