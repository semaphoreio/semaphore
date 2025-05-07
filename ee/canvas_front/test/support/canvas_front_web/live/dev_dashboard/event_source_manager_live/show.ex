defmodule CanvasFrontWeb.DevDashboard.EventSourceManagerLive.Show do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case CanvasFront.Stores.EventSource.get(%{id: id}) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Event Source not found")
         |> redirect(to: ~p"/dev/canvas-manager/event-sources")}

      event_source ->
        # Get the canvas for this event source
        canvas =
          case CanvasFront.Stores.Canvas.get(%{id: event_source.canvas_id}) do
            nil -> nil
            canvas -> canvas
          end

        {:ok,
         socket
         |> assign(:event_source, event_source)
         |> assign(:canvas, canvas)
         |> assign(:page_title, "Event Source: #{event_source.name}")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _, socket) do
    id = socket.assigns.event_source.id
    canvas_id = socket.assigns.event_source.canvas_id

    # Delete the event source
    case Support.Stubs.Delivery.delete_event_source(id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Event Source deleted successfully")
         |> redirect(to: ~p"/dev/canvas-manager/canvases/#{canvas_id}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error deleting event source: #{reason}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Event Source Details</h1>
        <div class="flex space-x-3">
          <.link
            navigate={~p"/dev/canvas-manager/event-sources/#{@event_source.id}/edit"}
            class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-pencil" class="h-4 w-4 mr-2" /> Edit Event Source
          </.link>
          <button
            phx-click="delete"
            phx-disable-with="Deleting..."
            data-confirm="Are you sure you want to delete this event source? This action cannot be undone."
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
          >
            <.icon name="hero-trash" class="h-4 w-4 mr-2" /> Delete Event Source
          </button>
        </div>
      </div>

      <div class="bg-white shadow overflow-hidden sm:rounded-lg mb-8">
        <div class="px-4 py-5 sm:px-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Event Source Information</h3>
          <p class="mt-1 max-w-2xl text-sm text-gray-500">Event source details and properties.</p>
        </div>
        <div class="border-t border-gray-200 px-4 py-5 sm:p-0">
          <dl class="sm:divide-y sm:divide-gray-200">
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Name</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{@event_source.name}</dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">ID</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{@event_source.id}</dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Canvas</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <%= if @canvas do %>
                  <.link
                    navigate={~p"/dev/canvas-manager/canvases/#{@canvas.id}"}
                    class="text-blue-600 hover:text-blue-900"
                  >
                    {@canvas.name}
                  </.link>
                <% else %>
                  {@event_source.canvas_id} (Canvas not found)
                <% end %>
              </dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Type</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                {@event_source[:type] || "Default"}
              </dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Position</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                {format_position(@event_source[:position])}
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <div class="mt-8 flex space-x-4">
        <.link
          navigate={~p"/dev/canvas-manager/event-sources"}
          class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Event Sources
        </.link>

        <%= if @canvas do %>
          <.link
            navigate={~p"/dev/canvas-manager/canvases/#{@canvas.id}"}
            class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
          >
            <.icon name="hero-document-text" class="h-4 w-4 mr-2" /> View Canvas
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_position(%{x: x, y: y} = _position) when is_number(x) and is_number(y) do
    "x: #{x}, y: #{y}"
  end

  defp format_position(_position), do: "No position"
end
