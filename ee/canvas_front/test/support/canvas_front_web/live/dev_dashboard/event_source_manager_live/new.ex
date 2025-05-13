defmodule CanvasFrontWeb.DevDashboard.EventSourceManagerLive.New do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    # Get all canvases for the dropdown
    canvases = Support.Stubs.Delivery.list_canvases()

    # Initialize with canvas_id from params if available
    canvas_id = params["canvas_id"] || List.first(canvases, %{}).id

    {:ok,
     socket
     |> assign(:page_title, "New Event Source")
     |> assign(:canvases, canvases)
     |> assign(:canvas_id, canvas_id)
     |> assign(:event_source, %{
       name: "",
       canvas_id: canvas_id,
       position: %{
         x: 100,
         y: 100
       },
       type: "webhook"
     })}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"event_source" => event_source_params}, socket) do
    position = %{
      x: parse_int(event_source_params["position_x"]),
      y: parse_int(event_source_params["position_y"])
    }

    # Create new event source
    params = %{
      name: event_source_params["name"],
      canvas_id: event_source_params["canvas_id"],
      position: position,
      type: event_source_params["type"]
    }

    case Support.Stubs.Delivery.seed_event_source(params) do
      %{id: id} = event_source ->
        # Dispatch event source creation event
        Support.Events.event_source_created(event_source.canvas_id, id)
        
        {:noreply,
         socket
         |> put_flash(:info, "Event Source created successfully!")
         |> redirect(to: ~p"/dev/canvas-manager/event-sources/#{id}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Error creating event source")
         |> assign(
           :event_source,
           Map.merge(socket.assigns.event_source, %{
             name: event_source_params["name"],
             canvas_id: event_source_params["canvas_id"],
             type: event_source_params["type"]
           })
         )}
    end
  end

  @impl true
  def handle_event("validate", %{"event_source" => event_source_params}, socket) do
    updated_event_source =
      Map.merge(socket.assigns.event_source, %{
        name: event_source_params["name"],
        canvas_id: event_source_params["canvas_id"],
        type: event_source_params["type"]
      })

    {:noreply,
     socket
     |> assign(:event_source, updated_event_source)
     |> assign(:position_x, parse_int(event_source_params["position_x"]))
     |> assign(:position_y, parse_int(event_source_params["position_y"]))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">New Event Source</h1>
        <p class="mt-2 text-sm text-gray-600">
          Create a new event source for a canvas stage
        </p>
      </div>

      <.form :let={f} for={%{}} as={:event_source} phx-change="validate" phx-submit="save">
        <div class="space-y-6 bg-white shadow sm:rounded-md p-6">
          <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
            <div class="sm:col-span-6">
              <.input
                field={f[:name]}
                type="text"
                label="Event Source Name"
                value={@event_source.name}
                required
              />
            </div>

            <div class="sm:col-span-6">
              <label for="canvas_id" class="block text-sm font-medium text-gray-700">Canvas</label>
              <select
                id="canvas_id"
                name="event_source[canvas_id]"
                class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
                required
              >
                <option value="" disabled selected={!@event_source.canvas_id}>Select Canvas</option>
                <%= for canvas <- @canvases do %>
                  <option value={canvas.id} selected={@event_source.canvas_id == canvas.id}>
                    {canvas.name}
                  </option>
                <% end %>
              </select>
            </div>

            <div class="sm:col-span-6">
              <label for="type" class="block text-sm font-medium text-gray-700">Type</label>
              <select
                id="type"
                name="event_source[type]"
                class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
              >
                <option value="webhook" selected={@event_source.type == "webhook"}>Webhook</option>
                <option value="api" selected={@event_source.type == "api"}>API</option>
                <option value="schedule" selected={@event_source.type == "schedule"}>Schedule</option>
                <option value="manual" selected={@event_source.type == "manual"}>Manual</option>
              </select>
            </div>

            <div class="sm:col-span-3">
              <.input
                field={f[:position_x]}
                type="number"
                label="Position X"
                value={@event_source.position.x}
                required
              />
            </div>

            <div class="sm:col-span-3">
              <.input
                field={f[:position_y]}
                type="number"
                label="Position Y"
                value={@event_source.position.y}
                required
              />
            </div>
          </div>

          <div class="flex justify-end space-x-3">
            <.link
              navigate={~p"/dev/canvas-manager/event-sources"}
              class="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Cancel
            </.link>
            <.button type="submit" phx-disable-with="Creating...">
              Create Event Source
            </.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp parse_int(value) when is_integer(value), do: value
  defp parse_int(_), do: 0
end
