defmodule GithubNotifier.Services.PipelineStartedNotifier do
  require Logger

  alias GithubNotifier.{Notifier, Utils}

  # ~15 min of redelivery before dead-lettering — rides out provider outages
  # and busy delivery-guard leases instead of dropping the status.
  @retry_delay 30
  @retry_limit 30

  use Tackle.Consumer,
    url: Application.get_env(:github_notifier, :amqp_url),
    exchange: "pipeline_state_exchange",
    routing_key: "running",
    service: "github_notifier.pipeline_started_notifier",
    connection_id: :block_notifier,
    dead_letter_queue: Application.get_env(:github_notifier, :tackle_dead_letter_queue, true),
    retry_delay: @retry_delay,
    retry_limit: @retry_limit

  @doc false
  def retry_config, do: %{retry_delay: @retry_delay, retry_limit: @retry_limit}

  def handle_message(message) do
    Watchman.benchmark("pipeline_started_notifier.duration", fn ->
      # We fall a sleep for a second because pipeline do not have blocks at start.
      :timer.sleep(1000)

      request_id = Utils.RandomString.random_string(30)

      event = InternalApi.Plumber.PipelineEvent.decode(message)

      Logger.info("[#{request_id}] Processing: PipelineStarted #{event.pipeline_id}")

      Notifier.notify(request_id, event.pipeline_id)

      Logger.info("[#{request_id}] Processing finished: PipelineStarted #{event.pipeline_id}")
    end)
  end
end
