defmodule CanvasFrontWeb.DevDashboard.EventSourceManagerLive.Index do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    # Fetch event sources
    event_sources = CanvasFront.Stores.EventSource.list(%{canvas_id: params["canvas_id"]})

    # Filter by canvas_id if provided
    event_sources =
      case params do
        %{"canvas_id" => canvas_id} when is_binary(canvas_id) and canvas_id != "" ->
          Enum.filter(event_sources, fn es -> es.canvas_id == canvas_id end)

        _ ->
          event_sources
      end

    # Get all canvases for the filter dropdowns
    canvases = Support.Stubs.Delivery.list_canvases()

    {:ok,
     socket
     |> assign(:event_sources, event_sources)
     |> assign(:canvases, canvases)
     |> assign(:canvas_id, params["canvas_id"])
     |> assign(:page_title, "Event Source Manager")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Event Source Manager")
  end

  @impl true
  def handle_event("filter-canvas", %{"canvas_id" => canvas_id}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/dev/canvas-manager/event-sources?canvas_id=#{canvas_id}")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center mb-8">
        <div class="sm:flex-auto">
          <h1 class="text-3xl font-bold">Event Source Manager</h1>
          <p class="mt-2 text-sm text-gray-600">
            Create and manage event sources for development
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <.link
            navigate={~p"/dev/canvas-manager/event-sources/new#{query_params(assigns)}"}
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-plus" class="h-4 w-4 mr-2" /> New Event Source
          </.link>
        </div>
      </div>
      
    <!-- Filters -->
      <div class="mb-6 bg-white shadow rounded-lg p-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <form phx-change="filter-canvas">
              <div>
                <label for="canvas_id" class="block text-sm font-medium text-gray-700">
                  Filter by Canvas
                </label>
                <div class="mt-1 flex items-center">
                  <select
                    id="canvas_id"
                    name="canvas_id"
                    class="block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
                  >
                    <option value="">All Canvases</option>
                    <%= for canvas <- @canvases do %>
                      <option value={canvas.id} selected={@canvas_id == canvas.id}>
                        {canvas.name}
                      </option>
                    <% end %>
                  </select>
                </div>
              </div>
            </form>
          </div>
        </div>

        <%= if @canvas_id do %>
          <div class="mt-4 flex justify-end">
            <.link
              navigate={~p"/dev/canvas-manager/event-sources"}
              class="text-sm text-blue-600 hover:text-blue-900"
            >
              Clear all filters
            </.link>
          </div>
        <% end %>
      </div>

      <div class="mt-4 flex flex-col">
        <div class="-my-2 -mx-4 overflow-x-auto sm:-mx-6 lg:-mx-8">
          <div class="inline-block min-w-full py-2 align-middle md:px-6 lg:px-8">
            <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
              <table class="min-w-full divide-y divide-gray-300">
                <thead class="bg-gray-50">
                  <tr>
                    <th
                      scope="col"
                      class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-6"
                    >
                      Name
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Canvas
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Type
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Position
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= if Enum.empty?(@event_sources) do %>
                    <tr>
                      <td colspan="5" class="py-6 text-center text-sm text-gray-500">
                        No event sources available.
                        <.link
                          navigate={~p"/dev/canvas-manager/event-sources/new"}
                          class="text-blue-600 hover:text-blue-900"
                        >
                          Create one
                        </.link>
                      </td>
                    </tr>
                  <% else %>
                    <%= for event_source <- @event_sources do %>
                      <tr id={"event-source-#{event_source.id}"}>
                        <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                          {event_source.name}
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          {get_canvas_name(event_source.canvas_id, @canvases)}
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          {event_source[:type] || "N/A"}
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          {format_position(event_source[:position])}
                        </td>
                        <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                          <div class="flex justify-end space-x-2">
                            <.link
                              navigate={~p"/dev/canvas-manager/event-sources/#{event_source.id}"}
                              class="text-blue-600 hover:text-blue-900"
                            >
                              View<span class="sr-only">, <%= event_source.name %></span>
                            </.link>

                            <.link
                              navigate={~p"/dev/canvas-manager/event-sources/#{event_source.id}/edit"}
                              class="text-blue-600 hover:text-blue-900"
                            >
                              Edit<span class="sr-only">, <%= event_source.name %></span>
                            </.link>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <.link
          navigate={~p"/dev/canvas-manager"}
          class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Dashboard
        </.link>
      </div>
    </div>
    """
  end

  defp get_canvas_name(canvas_id, canvases) do
    case Enum.find(canvases, fn canvas -> canvas.id == canvas_id end) do
      nil -> canvas_id
      canvas -> canvas.name
    end
  end

  defp format_position(%{x: x, y: y} = _position) when is_number(x) and is_number(y) do
    "x: #{x}, y: #{y}"
  end

  defp format_position(_position), do: "No position"

  defp query_params(assigns) do
    case assigns.canvas_id do
      nil -> ""
      canvas_id -> "?canvas_id=#{canvas_id}"
    end
  end
end
