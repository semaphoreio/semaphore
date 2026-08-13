defmodule GithubNotifier.Services.PipelineFinishedNotifier do
  require Logger

  alias GithubNotifier.{Notifier, Utils}

  # ~15 min of redelivery before dead-lettering — rides out provider outages
  # and busy delivery-guard leases instead of dropping the status.
  @retry_delay 30
  @retry_limit 30

  use Tackle.Consumer,
    url: Application.get_env(:github_notifier, :amqp_url),
    exchange: "pipeline_state_exchange",
    routing_key: "done",
    service: "github_notifier.pipeline_finished_notifier",
    connection_id: :block_notifier,
    dead_letter_queue: Application.get_env(:github_notifier, :tackle_dead_letter_queue, true),
    retry_delay: @retry_delay,
    retry_limit: @retry_limit

  @doc false
  def retry_config, do: %{retry_delay: @retry_delay, retry_limit: @retry_limit}

  def handle_message(message) do
    Watchman.benchmark("pipeline_finished_notifier.duration", fn ->
      request_id = Utils.RandomString.random_string(30)

      event = InternalApi.Plumber.PipelineEvent.decode(message)

      Logger.info("[#{request_id}] Processing: PipelineFinished #{event.pipeline_id}")

      Notifier.notify(request_id, event.pipeline_id)

      Logger.info("[#{request_id}] Processing finished: PipelineFinished #{event.pipeline_id}")
    end)
  end
end
