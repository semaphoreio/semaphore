defmodule HooksProcessor.RabbitMQConsumer do
  @moduledoc """
  Receives hooks data from the RabbitMQ, stores them in DB and initiates
  processing.
  """

  alias HooksProcessor.Hooks.Processing.WorkersSupervisor
  alias HooksProcessor.Hooks.Model.HooksQueries
  alias InternalApi.Hooks.ReceivedWebhook

  alias HooksProcessor.Clients.RepositoryClient
  alias Util.Metrics
  alias LogTee, as: LT

  use Tackle.Consumer,
    url: Application.get_env(:hooks_processor, :amqp_url),
    exchange: "received_webhooks_exchange",
    routing_key: provider(),
    service: "hooks_processor"

  def provider, do: Application.get_env(:hooks_processor, :webhook_provider)

  def handle_message(message) do
    Metrics.benchmark("RabbitMQConsumer.received_webhook", [provider()], fn ->
      with {:ok, decoded_message} <- decode_message(message),
           {:ok, true} <- verify_webhook_signature(decoded_message, provider()),
           {:ok, webhook} <- store_webhook(decoded_message) do
        start_worker(webhook)
      else
        {:ok, false} ->
          :ok

        {:error, error} ->
          LT.error(error, "Error while processing received_webhook RabbitMQ message")
      end
    end)
  end

  def decode_message(message) do
    Wormhole.capture(
      fn ->
        decoded =
          message
          |> ReceivedWebhook.decode()
          |> Map.from_struct()
          |> Map.update!(:received_at, &timestamp_to_datetime/1)

        webhook = JSON.decode!(decoded.webhook)

        %{decoded | webhook: webhook} |> Map.put(:provider, provider())
      end,
      stacktrace: true
    )
  end

  def timestamp_to_datetime(%{nanos: 0, seconds: 0}), do: :invalid_datetime

  def timestamp_to_datetime(%{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)
    ts_date_time
  end

  defp verify_webhook_signature(decoded_message, _) do
    RepositoryClient.verify_webhook_signature(
      decoded_message.organization_id,
      decoded_message.repository_id,
      decoded_message.webhook_raw_payload,
      decoded_message.webhook_signature
    )
    |> case do
      {:ok, true} ->
        Watchman.increment({"hooks.processing.verify_signature.success", [provider()]})

        {:ok, true}

      {:ok, false} ->
        Watchman.increment({"hooks.processing.verify_signature.fail", [provider()]})
        LT.warn(decoded_message.repository_id, "Webhook signature verification failed for repository")

        {:ok, false}

      error ->
        Watchman.increment({"hooks.processing.verify_signature.error", [provider()]})
        LT.error(error, "Webhook signature verification errored")

        raise "Webhook signature verification errored"
    end
  end

  defp store_webhook(webhook) do
    HooksQueries.insert(webhook)
  end

  defp start_worker(webhook) do
    WorkersSupervisor.start_worker_for_webhook(webhook.id)
  end
end
