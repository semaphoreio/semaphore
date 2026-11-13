defmodule GithubNotifier.Services.BlockFinishedNotifier do
  require Logger

  alias GithubNotifier.{Notifier, Utils}

  # ~15 min of redelivery before dead-lettering — rides out provider outages
  # and busy delivery-guard leases instead of dropping the status.
  @retry_delay 30
  @retry_limit 30

  # Tackle handles each delivery in its own process, so prefetch is the
  # concurrency. Per-check ordering is enforced downstream by StatusSender.
  @prefetch_count_env "BLOCK_FINISHED_PREFETCH_COUNT"
  @default_prefetch_count 10

  use Tackle.Consumer,
    url: Application.get_env(:github_notifier, :amqp_url),
    exchange: "pipeline_block_state_exchange",
    routing_key: "done",
    service: "github_notifier.block_finished_notifier",
    connection_id: :block_notifier,
    dead_letter_queue: Application.get_env(:github_notifier, :tackle_dead_letter_queue, true),
    retry_delay: @retry_delay,
    retry_limit: @retry_limit,
    prefetch_count: __MODULE__.prefetch_count()

  @doc false
  def retry_config, do: %{retry_delay: @retry_delay, retry_limit: @retry_limit}

  @doc false
  def prefetch_count do
    case System.get_env(@prefetch_count_env) do
      nil -> @default_prefetch_count
      value -> parse_prefetch_count(value)
    end
  end

  # A prefetch of 0 means unlimited to the broker, so it is rejected too.
  defp parse_prefetch_count(value) do
    case Integer.parse(value) do
      {count, ""} when count > 0 ->
        count

      _ ->
        Logger.warning(
          "Ignoring invalid #{@prefetch_count_env}, using #{@default_prefetch_count}"
        )

        @default_prefetch_count
    end
  end

  def handle_message(message) do
    Watchman.benchmark("block_finished_notifier.duration", fn ->
      # we are waiting for pipeline to update the status
      # this event updates the status just after the pipeline event,
      # but pipeline here may still be running.
      Process.sleep(1000)

      request_id = Utils.RandomString.random_string(30)
      event = InternalApi.Plumber.PipelineBlockEvent.decode(message)

      Logger.info(
        "[#{request_id}] Processing: BlockFinished #{event.pipeline_id} #{event.block_id}"
      )

      Notifier.notify(request_id, event.pipeline_id, event.block_id)

      Logger.info(
        "[#{request_id}] Processing finished: BlockFinished #{event.pipeline_id} #{event.block_id}"
      )
    end)
  end
end
