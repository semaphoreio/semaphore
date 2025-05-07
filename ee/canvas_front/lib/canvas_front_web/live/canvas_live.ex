defmodule CanvasFrontWeb.CanvasLive do
  use CanvasFrontWeb, :live_view

  require Logger
  alias CanvasFrontWeb.Endpoint

  @impl true
  def mount(%{"canvas_id" => canvas_id}, _session, socket) do
    canvas =
      CanvasFront.Stores.Canvas.get(%{id: canvas_id})
      |> Map.update!(:created_at, &ts_to_iso/1)

    Logger.info("Canvas: #{inspect(canvas)}")

    stages =
      CanvasFront.Stores.Stage.list(%{canvas_id: canvas_id})
      |> Enum.map(fn stage -> Map.update!(stage, :created_at, &ts_to_iso/1) end)

    Logger.info("Stages: #{inspect(stages)}")

    event_sources =
      CanvasFront.Stores.EventSource.list(%{canvas_id: canvas_id})
      |> Enum.map(fn es -> Map.update!(es, :created_at, &ts_to_iso/1) end)

    Logger.info("Event Sources: #{inspect(event_sources)}")

    # assign initial socket assigns
    socket =
      assign(socket,
        canvas_id: canvas_id,
        stages: stages,
        canvas: canvas,
        event_sources: event_sources,
        executions: []
      )

    # subscribe to PubSub topic for live updates
    if connected?(socket) do
      Endpoint.subscribe("canvas:" <> canvas_id)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "canvas_updated", payload: new_canvas}, socket) do
    {:noreply, push_event(socket, "canvas_updated", new_canvas)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "stage_added", payload: stage}, socket) do
    # Convert any timestamp to ISO format if needed
    stage =
      if Map.has_key?(stage, :created_at) do
        Map.update!(stage, :created_at, &ts_to_iso/1)
      else
        stage
      end

    {:noreply, push_event(socket, "stage_added", stage)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "event_source_added", payload: event_source},
        socket
      ) do
    # Convert any timestamp to ISO format if needed
    event_source =
      if Map.has_key?(event_source, :created_at) do
        Map.update!(event_source, :created_at, &ts_to_iso/1)
      else
        event_source
      end

    {:noreply, push_event(socket, "event_source_added", event_source)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "stage_created", payload: stage}, socket) do
    stage =
      if Map.has_key?(stage, :created_at) do
        Map.update!(stage, :created_at, &ts_to_iso/1)
      else
        stage
      end

    stages = [stage | socket.assigns.stages]
    {:noreply, socket |> assign(:stages, stages) |> push_event("stage_created", stage)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "stage_event_created", payload: event}, socket) do
    {:noreply, push_event(socket, "stage_event_created", event)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "stage_event_approved", payload: event},
        socket
      ) do
    {:noreply, push_event(socket, "stage_event_approved", event)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "execution_created", payload: execution},
        socket
      ) do
    execution =
      if Map.has_key?(execution, :created_at) do
        Map.update!(execution, :created_at, &ts_to_iso/1)
      else
        execution
      end

    executions = [execution | socket.assigns.executions]

    {:noreply,
     socket |> assign(:executions, executions) |> push_event("execution_created", execution)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "execution_started", payload: execution},
        socket
      ) do
    updated_executions =
      Enum.map(socket.assigns.executions, fn existing ->
        if existing.id == execution.id do
          if Map.has_key?(execution, :started_at) do
            Map.update!(execution, :started_at, &ts_to_iso/1)
          else
            execution
          end
        else
          existing
        end
      end)

    {:noreply,
     socket
     |> assign(:executions, updated_executions)
     |> push_event("execution_started", execution)}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "execution_finished", payload: execution},
        socket
      ) do
    updated_executions =
      Enum.map(socket.assigns.executions, fn existing ->
        if existing.id == execution.id do
          if Map.has_key?(execution, :finished_at) do
            Map.update!(execution, :finished_at, &ts_to_iso/1)
          else
            execution
          end
        else
          existing
        end
      end)

    {:noreply,
     socket
     |> assign(:executions, updated_executions)
     |> push_event("execution_finished", execution)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: payload}, socket) do
    Logger.debug("Received unhandled event: #{event} with payload: #{inspect(payload)}")
    {:noreply, socket}
  end

  def update_stage_with_event(stages, event) do
    Enum.map(stages, fn stage ->
      if stage.id == event.stage_id do
        stage
      else
        stage
      end
    end)
  end

  defp ts_to_iso(%Google.Protobuf.Timestamp{seconds: s, nanos: _}) do
    DateTime.from_unix!(s, :second)
    |> DateTime.to_iso8601()
  end
end
