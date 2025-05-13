defmodule Support.Events do
  def stage_event_created(canvas_id, stage_id, event_id) do
    message = InternalApi.Delivery.StageEventCreated.encode(%InternalApi.Delivery.StageEventCreated{
      canvas_id: canvas_id,
      stage_id: stage_id,
      event_id: event_id
    })

    CanvasFront.CanvasConsumer.event_created(message)
  end

  def stage_event_approved(canvas_id, stage_id, event_id) do
    message = InternalApi.Delivery.StageEventApproved.encode(%InternalApi.Delivery.StageEventApproved{
      canvas_id: canvas_id,
      stage_id: stage_id,
      event_id: event_id
    })

    CanvasFront.CanvasConsumer.event_approved(message)
  end

  def event_source_created(canvas_id, source_id) do
    message = InternalApi.Delivery.EventSourceCreated.encode(%InternalApi.Delivery.EventSourceCreated{
      canvas_id: canvas_id,
      source_id: source_id
    })

    CanvasFront.CanvasConsumer.event_source_created(message)
  end

  def stage_execution_created(canvas_id, stage_id, execution_id) do
    message = InternalApi.Delivery.StageExecutionCreated.encode(%InternalApi.Delivery.StageExecutionCreated{
      canvas_id: canvas_id,
      stage_id: stage_id,
      execution_id: execution_id
    })

    CanvasFront.CanvasConsumer.execution_created(message)
  end

  def stage_execution_started(canvas_id, stage_id, execution_id) do
    message = InternalApi.Delivery.StageExecutionStarted.encode(%InternalApi.Delivery.StageExecutionStarted{
      canvas_id: canvas_id,
      stage_id: stage_id,
      execution_id: execution_id
    })

    CanvasFront.CanvasConsumer.execution_started(message)
  end

  def stage_execution_finished(canvas_id, stage_id, execution_id) do
    message = InternalApi.Delivery.StageExecutionFinished.encode(%InternalApi.Delivery.StageExecutionFinished{
      canvas_id: canvas_id,
      stage_id: stage_id,
      execution_id: execution_id
    })

    CanvasFront.CanvasConsumer.execution_finished(message)
  end

  def stage_created(canvas_id, stage_id) do
    message = InternalApi.Delivery.StageCreated.encode(%InternalApi.Delivery.StageCreated{
      canvas_id: canvas_id,
      stage_id: stage_id
    })

    CanvasFront.CanvasConsumer.stage_created(message)
  end

  def stage_updated(canvas_id, stage_id) do
    message = InternalApi.Delivery.StageUpdated.encode(%InternalApi.Delivery.StageUpdated{
      canvas_id: canvas_id,
      stage_id: stage_id
    })

    CanvasFront.CanvasConsumer.stage_updated(message)
  end
end
