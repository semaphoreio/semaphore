defmodule GithubNotifier.Services.PipelineSummaryAvailableNotifier do
  require Logger

  alias GithubNotifier.{Notifier, Utils}

  alias InternalApi.Velocity.PipelineSummaryAvailableEvent

  use Tackle.Consumer,
    url: Application.get_env(:github_notifier, :amqp_url),
    exchange: "velocity_pipeline_summary_exchange",
    routing_key: "done",
    service: "github_notifier.pipeline_summary_notifier",
    connection_id: :pipeline_summary_notifier

  def handle_message(message) do
    Watchman.benchmark("pipeline_summary_notifier.duration", fn ->
      request_id = Utils.RandomString.random_string(30)
      Logger.metadata(request_id: request_id)

      event = PipelineSummaryAvailableEvent.decode(message)

      Logger.info("Processing: Pipeline summary available #{event.pipeline_id}")

      Notifier.notify_with_summary(request_id, event.pipeline_id)

      Logger.info("Processing finished: Pipeline summary available #{event.pipeline_id}")
    end)
  end
end
