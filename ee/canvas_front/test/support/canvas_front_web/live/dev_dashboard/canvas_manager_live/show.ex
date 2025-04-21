defmodule CanvasFrontWeb.DevDashboard.CanvasManagerLive.Show do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case CanvasFront.Stores.Canvas.get(%{id: id}) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Canvas not found")
         |> redirect(to: ~p"/dev/canvas-manager/canvases")}

      canvas ->
        stages = CanvasFront.Stores.Stage.list(%{canvas_id: canvas.id})
        event_sources = CanvasFront.Stores.EventSource.list(%{canvas_id: canvas.id})

        {:ok,
         socket
         |> assign(:canvas, canvas)
         |> assign(:stages, stages)
         |> assign(:event_sources, event_sources)
         |> assign(:page_title, "Canvas: #{canvas.name}")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Canvas Details</h1>
        <div class="flex space-x-3">
          <.link
            navigate={~p"/dev/canvas-manager/canvases/#{@canvas.id}/edit"}
            class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-pencil" class="h-4 w-4 mr-2" /> Edit Canvas
          </.link>
          <.link
            navigate={~p"/canvas/#{@canvas.id}"}
            target="_blank"
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-arrow-top-right-on-square" class="h-4 w-4 mr-2" /> Open Canvas
          </.link>
        </div>
      </div>

      <div class="bg-white shadow overflow-hidden sm:rounded-lg mb-8">
        <div class="px-4 py-5 sm:px-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Canvas Information</h3>
          <p class="mt-1 max-w-2xl text-sm text-gray-500">Canvas details and properties.</p>
        </div>
        <div class="border-t border-gray-200 px-4 py-5 sm:p-0">
          <dl class="sm:divide-y sm:divide-gray-200">
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Name</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{@canvas.name}</dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">ID</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{@canvas.id}</dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Organization</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                {@canvas.organization_id}
              </dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Created By</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{@canvas.created_by}</dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Created At</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                {format_timestamp(@canvas.created_at)}
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <div class="flex flex-col md:flex-row gap-8">
        <!-- Stages -->
        <div class="flex-1">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-bold">Stages</h2>
            <.link
              navigate={~p"/dev/canvas-manager/stages/new?canvas_id=#{@canvas.id}"}
              class="inline-flex items-center px-3 py-1.5 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <.icon name="hero-plus" class="h-4 w-4 mr-1" /> Add Stage
            </.link>
          </div>

          <div class="bg-white shadow overflow-hidden sm:rounded-lg">
            <%= if Enum.empty?(@stages) do %>
              <div class="p-6 text-center text-gray-500">
                No stages found for this canvas.
              </div>
            <% else %>
              <ul class="divide-y divide-gray-200">
                <%= for stage <- @stages do %>
                  <li class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div>
                        <h3 class="text-sm font-medium text-gray-900">{stage.name}</h3>
                        <p class="text-xs text-gray-500">ID: {stage.id}</p>
                      </div>
                      <div class="flex space-x-2">
                        <.link
                          navigate={~p"/dev/canvas-manager/stages/#{stage.id}"}
                          class="text-blue-600 hover:text-blue-900 text-sm"
                        >
                          View
                        </.link>
                        <.link
                          navigate={~p"/dev/canvas-manager/stages/#{stage.id}/edit"}
                          class="text-blue-600 hover:text-blue-900 text-sm"
                        >
                          Edit
                        </.link>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </div>
        
    <!-- Event Sources -->
        <div class="flex-1">
          <div class="flex justify-between items-center mb-4">
            <h2 class="text-xl font-bold">Event Sources</h2>
            <.link
              navigate={~p"/dev/canvas-manager/event-sources/new?canvas_id=#{@canvas.id}"}
              class="inline-flex items-center px-3 py-1.5 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <.icon name="hero-plus" class="h-4 w-4 mr-1" /> Add Event Source
            </.link>
          </div>

          <div class="bg-white shadow overflow-hidden sm:rounded-lg">
            <%= if Enum.empty?(@event_sources) do %>
              <div class="p-6 text-center text-gray-500">
                No event sources found for this canvas.
              </div>
            <% else %>
              <ul class="divide-y divide-gray-200">
                <%= for event_source <- @event_sources do %>
                  <li class="px-6 py-4">
                    <div class="flex items-center justify-between">
                      <div>
                        <h3 class="text-sm font-medium text-gray-900">{event_source.name}</h3>
                        <p class="text-xs text-gray-500">ID: {event_source.id}</p>
                      </div>
                      <div class="flex space-x-2">
                        <.link
                          navigate={~p"/dev/canvas-manager/event-sources/#{event_source.id}"}
                          class="text-blue-600 hover:text-blue-900 text-sm"
                        >
                          View
                        </.link>
                        <.link
                          navigate={~p"/dev/canvas-manager/event-sources/#{event_source.id}/edit"}
                          class="text-blue-600 hover:text-blue-900 text-sm"
                        >
                          Edit
                        </.link>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            <% end %>
          </div>
        </div>
      </div>

      <div class="mt-8">
        <.link
          navigate={~p"/dev/canvas-manager/canvases"}
          class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Canvases
        </.link>
      </div>
    </div>
    """
  end

  defp format_timestamp(%{seconds: seconds} = _timestamp) when is_integer(seconds) do
    {:ok, datetime} = DateTime.from_unix(seconds)
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_timestamp(_timestamp), do: "N/A"
end
