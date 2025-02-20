defmodule GithubNotifier.Services.BlockFinishedNotifier do
  require Logger

  alias GithubNotifier.{Notifier, Utils}

  use Tackle.Consumer,
    url: Application.get_env(:github_notifier, :amqp_url),
    exchange: "pipeline_block_state_exchange",
    routing_key: "done",
    service: "github_notifier.block_finished_notifier",
    connection_id: :block_notifier

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
