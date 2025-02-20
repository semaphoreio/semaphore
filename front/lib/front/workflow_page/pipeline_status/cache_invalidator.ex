defmodule Front.WorkflowPage.PipelineStatus.CacheInvalidator do
  alias Front.WorkflowPage.PipelineStatus.Model
  require Logger

  @doc """
  This module consumes RabbitMQ pipeline state change events
  and invalidates pipeline status cache for received
  pipeline_id from event message.
  """

  use Tackle.Multiconsumer,
    url: Application.get_env(:front, :amqp_url),
    service: "#{Application.get_env(:front, :cache_reactor_env)}.pipeline_status_invalidator",
    service_per_exchange: true,
    routes: [
      {"pipeline_state_exchange", "initializing", :pipeline_event},
      {"pipeline_state_exchange", "pending", :pipeline_event},
      {"pipeline_state_exchange", "queuing", :pipeline_event},
      {"pipeline_state_exchange", "running", :pipeline_event},
      {"pipeline_state_exchange", "stopping", :pipeline_event},
      {"pipeline_state_exchange", "done", :pipeline_event}
    ]

  def pipeline_event(message) do
    event = message |> InternalApi.Plumber.PipelineEvent.decode()
    event.pipeline_id |> Model.invalidate()
    Logger.info("[PIPELINE STATUS INVALIDATOR] #{event.pipeline_id}")
  rescue
    e in Protobuf.DecodeError ->
      Logger.error(
        "[PIPELINE STATUS INVALIDATOR] Processing failed message: #{inspect(message)} error: #{inspect(e)}"
      )
  end
end
