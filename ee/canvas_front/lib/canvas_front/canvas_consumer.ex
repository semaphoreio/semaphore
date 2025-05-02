defmodule CanvasFront.CanvasConsumer do
  require Logger

  use Tackle.Multiconsumer,
    url: Application.get_env(:canvas_front, :amqp_url),
    service: "canvas_consumer.#{Application.get_env(:canvas_front, :unique_service_name)}",
    service_per_exchange: true,
    routes: [
      {"delivery-hub.canvas-exchange", "stage-event-created", :event_created},
      {"delivery-hub.canvas-exchange", "stage-event-approved", :event_approved},
      {"delivery-hub.canvas-exchange", "event-source-created", :event_source_created},
      {"delivery-hub.canvas-exchange", "execution-created", :execution_created},
      {"delivery-hub.canvas-exchange", "execution-started", :execution_started},
      {"delivery-hub.canvas-exchange", "execution-finished", :execution_finished},
      {"delivery-hub.canvas-exchange", "stage-created", :stage_created}
    ]

  @metric_name "canvas_consumer.process"
  @log_prefix "[CANVAS CONSUMER]"

  defp broadcast_to_canvas(canvas_id, event, payload) do
    topic = "canvas:" <> canvas_id

    CanvasFrontWeb.Endpoint.broadcast!(topic, event, payload)

    Logger.debug("#{@log_prefix} Broadcasted #{event} to #{topic}")
  end

  def event_created(message) do
    Watchman.benchmark({@metric_name, ["event-created"]}, fn ->
      decoded_message = InternalApi.Delivery.StageEventCreated.decode(message)

      event =
        CanvasFront.Stores.Event.get(%{
          id: decoded_message.event_id,
          stage_id: decoded_message.stage_id
        })

      if event do
        broadcast_to_canvas(
          decoded_message.canvas_id,
          "stage_event_created",
          event
        )
      end

      Logger.info(
        "#{@log_prefix} [EVENT CREATED] [canvas_id=#{decoded_message.canvas_id}] Processing finished"
      )
    end)
  end

  def event_approved(message) do
    Watchman.benchmark({@metric_name, ["event-approved"]}, fn ->
      decoded_message = InternalApi.Delivery.StageEventApproved.decode(message)

      event =
        CanvasFront.Stores.Event.get(%{
          id: decoded_message.event_id,
          stage_id: decoded_message.stage_id
        })

      if event do
        broadcast_to_canvas(
          decoded_message.canvas_id,
          "stage_event_approved",
          event
        )
      end

      Logger.info(
        "#{@log_prefix} [EVENT APPROVED] [canvas_id=#{decoded_message.canvas_id}] Processing finished"
      )
    end)
  end

  def event_source_created(message) do
    Watchman.benchmark({@metric_name, ["event-source-created"]}, fn ->
      decoded_message = InternalApi.Delivery.EventSourceCreated.decode(message)

      event_source =
        CanvasFront.Stores.EventSource.get(%{
          id: decoded_message.source_id,
          canvas_id: decoded_message.canvas_id
        })

      if event_source do
        broadcast_to_canvas(
          decoded_message.canvas_id,
          "event_source_added",
          event_source
        )
      end

      Logger.info(
        "#{@log_prefix} [EVENT SOURCE CREATED] [canvas_id=#{decoded_message.canvas_id}] Processing finished"
      )
    end)
  end

  def execution_created(message) do
    Watchman.benchmark({@metric_name, ["execution-created"]}, fn ->
      decoded_message = InternalApi.Delivery.StageExecutionCreated.decode(message)

      execution =
        CanvasFront.Stores.Execution.get(%{
          id: decoded_message.execution_id
        })

      if execution do
        broadcast_to_canvas(
          decoded_message.canvas_id,
          "execution_created",
          execution
        )
      end

      Logger.info(
        "#{@log_prefix} [EXECUTION CREATED] [canvas_id=#{decoded_message.canvas_id}] Processing finished"
      )
    end)
  end

  def execution_started(message) do
    Watchman.benchmark({@metric_name, ["execution-started"]}, fn ->
      decoded_message = InternalApi.Delivery.StageExecutionStarted.decode(message)

      execution =
        CanvasFront.Stores.Execution.get(%{
          id: decoded_message.execution_id
        })

      if execution do
        broadcast_to_canvas(
          decoded_message.canvas_id,
          "execution_started",
          execution
        )
      end

      Logger.info(
        "#{@log_prefix} [EXECUTION STARTED] [canvas_id=#{decoded_message.canvas_id}] Processing finished"
      )
    end)
  end

  def execution_finished(message) do
    Watchman.benchmark({@metric_name, ["execution-finished"]}, fn ->
      decoded_message = InternalApi.Delivery.StageExecutionFinished.decode(message)

      execution =
        CanvasFront.Stores.Execution.get(%{
          id: decoded_message.execution_id
        })

      if execution do
        broadcast_to_canvas(
          decoded_message.canvas_id,
          "execution_finished",
          execution
        )
      end

      Logger.info(
        "#{@log_prefix} [EXECUTION FINISHED] [canvas_id=#{decoded_message.canvas_id}] Processing finished"
      )
    end)
  end

  def stage_created(message) do
    Watchman.benchmark({@metric_name, ["stage-created"]}, fn ->
      decoded_message = InternalApi.Delivery.StageCreated.decode(message)

      stage =
        CanvasFront.Stores.Stage.get(%{
          id: decoded_message.stage_id,
          canvas_id: decoded_message.canvas_id
        })

      if stage do
        broadcast_to_canvas(
          decoded_message.canvas_id,
          "stage_created",
          stage
        )
      end

      Logger.info(
        "#{@log_prefix} [STAGE CREATED] [canvas_id=#{decoded_message.canvas_id}] Processing finished"
      )
    end)
  end
end
