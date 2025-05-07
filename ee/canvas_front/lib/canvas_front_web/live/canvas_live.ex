defmodule CanvasFrontWeb.CanvasLive do
  use CanvasFrontWeb, :live_view

  require Logger
  alias CanvasFrontWeb.Endpoint

  @impl true
  def mount(%{"canvas_id" => canvas_id}, _session, socket) do
    canvas =
      CanvasFront.Stores.Canvas.get(%{id: canvas_id})

    Logger.info("Canvas: #{inspect(canvas)}")

    stages =
      CanvasFront.Stores.Stage.list(%{canvas_id: canvas_id})

    Logger.info("Stages: #{inspect(stages)}")

    event_sources =
      CanvasFront.Stores.EventSource.list(%{canvas_id: canvas_id})

    Logger.info("Event Sources: #{inspect(event_sources)}")

    # assign initial socket assigns
    socket =
      assign(socket,
        canvas_id: canvas_id,
        stages: stages,
        canvas: canvas,
        event_sources: event_sources
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

  defp ts_to_iso(%Google.Protobuf.Timestamp{seconds: s, nanos: _}) do
    DateTime.from_unix!(s, :second)
    |> DateTime.to_iso8601()
  end
end
