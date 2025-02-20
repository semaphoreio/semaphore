defmodule GithubNotifier.Services.PipelineFinishedNotifier do
  require Logger

  alias GithubNotifier.{Notifier, Utils}

  use Tackle.Consumer,
    url: Application.get_env(:github_notifier, :amqp_url),
    exchange: "pipeline_state_exchange",
    routing_key: "done",
    service: "github_notifier.pipeline_finished_notifier",
    connection_id: :block_notifier

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
