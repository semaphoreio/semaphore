defmodule CanvasFrontWeb.DevDashboard.EventSourceManagerLive.Edit do
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
        # Extract position for form fields
        position = event_source[:position] || %{x: 0, y: 0}

        # Get all canvases for the dropdown
        canvases = CanvasFront.Stores.Canvas.list(%{})

        {:ok,
         socket
         |> assign(:event_source, event_source)
         |> assign(:canvases, canvases)
         |> assign(:position_x, position.x)
         |> assign(:position_y, position.y)
         |> assign(:page_title, "Edit Event Source: #{event_source.name}")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"event_source" => params}, socket) do
    position = %{
      x: parse_int(params["position_x"]),
      y: parse_int(params["position_y"])
    }

    # Update event source
    update_attrs = %{
      id: socket.assigns.event_source.id,
      name: params["name"],
      canvas_id: params["canvas_id"],
      position: position,
      type: params["type"]
    }

    case Support.Stubs.Delivery.update_event_source(update_attrs) do
      {:ok, event_source} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event Source updated successfully!")
         |> redirect(to: ~p"/dev/canvas-manager/event-sources/#{event_source.id}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error updating event source: #{reason}")
         |> assign(
           :event_source,
           Map.merge(socket.assigns.event_source, %{
             name: params["name"],
             canvas_id: params["canvas_id"],
             type: params["type"]
           })
         )
         |> assign(:position_x, position.x)
         |> assign(:position_y, position.y)}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Error updating event source")
         |> assign(
           :event_source,
           Map.merge(socket.assigns.event_source, %{
             name: params["name"],
             canvas_id: params["canvas_id"],
             type: params["type"]
           })
         )
         |> assign(:position_x, position.x)
         |> assign(:position_y, position.y)}
    end
  end

  @impl true
  def handle_event("validate", %{"event_source" => params}, socket) do
    # Update the form with the validated params
    updated_event_source =
      Map.merge(socket.assigns.event_source, %{
        name: params["name"],
        canvas_id: params["canvas_id"],
        type: params["type"]
      })

    {:noreply,
     socket
     |> assign(:event_source, updated_event_source)
     |> assign(:position_x, parse_int(params["position_x"]))
     |> assign(:position_y, parse_int(params["position_y"]))}
  end

  @impl true
  def handle_event("canvas-changed", %{"canvas_id" => canvas_id}, socket) do
    updated_event_source =
      Map.merge(socket.assigns.event_source, %{
        name: socket.assigns.event_source.name,
        canvas_id: canvas_id,
        type: socket.assigns.event_source.type
      })

    {:noreply,
     socket
     |> assign(:event_source, updated_event_source)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">Edit Event Source</h1>
        <p class="mt-2 text-sm text-gray-600">
          Update event source information
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
                <option value="default" selected={@event_source.type == "default"}>Default</option>
                <%!-- <option value="webhook" selected={@event_source.type == "webhook"}>Webhook</option>
                <option value="api" selected={@event_source.type == "api"}>API</option> --%>
              </select>
            </div>

            <div class="sm:col-span-3">
              <.input
                field={f[:position_x]}
                type="number"
                label="Position X"
                value={@position_x}
                required
              />
            </div>

            <div class="sm:col-span-3">
              <.input
                field={f[:position_y]}
                type="number"
                label="Position Y"
                value={@position_y}
                required
              />
            </div>

            <div class="sm:col-span-6">
              <p class="text-sm text-gray-500">
                Event Source ID: {@event_source.id} (cannot be changed)
              </p>
            </div>
          </div>

          <div class="flex justify-end space-x-3">
            <.link
              navigate={~p"/dev/canvas-manager/event-sources/#{@event_source.id}"}
              class="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Cancel
            </.link>
            <.button type="submit" phx-disable-with="Saving...">
              Save Changes
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
