defmodule CanvasFrontWeb.DevDashboard.CanvasManagerLive.Index do
  use CanvasFrontWeb, :live_view
  alias CanvasFront.Stores.Canvas

  @impl true
  def mount(_params, _session, socket) do
    # Fetch canvases from the service layer
    canvases = Support.Stubs.Delivery.list_canvases()

    {:ok,
     socket
     |> assign(:canvases, canvases)
     |> assign(:page_title, "Canvas Manager")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Canvas Manager")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="sm:flex sm:items-center mb-8">
        <div class="sm:flex-auto">
          <h1 class="text-3xl font-bold">Canvas Manager</h1>
          <p class="mt-2 text-sm text-gray-600">
            Create and manage canvases for development
          </p>
        </div>
        <div class="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <.link
            navigate={~p"/dev/canvas-manager/canvases/new"}
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-plus" class="h-4 w-4 mr-2" /> New Canvas
          </.link>
        </div>
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
                      Organization
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Created By
                    </th>
                    <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                      Created At
                    </th>
                    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-200 bg-white">
                  <%= if Enum.empty?(@canvases) do %>
                    <tr>
                      <td colspan="5" class="py-6 text-center text-sm text-gray-500">
                        No canvases available.
                        <.link
                          navigate={~p"/dev/canvas-manager/canvases/new"}
                          class="text-blue-600 hover:text-blue-900"
                        >
                          Create one
                        </.link>
                      </td>
                    </tr>
                  <% else %>
                    <%= for canvas <- @canvases do %>
                      <tr id={"canvas-#{canvas.id}"}>
                        <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-6">
                          {canvas.name}
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          {canvas.organization_id}
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          {canvas.created_by}
                        </td>
                        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                          {format_timestamp(canvas.created_at)}
                        </td>
                        <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                          <div class="flex justify-end space-x-2">
                            <.link
                              navigate={~p"/dev/canvas-manager/canvases/#{canvas.id}"}
                              class="text-blue-600 hover:text-blue-900"
                            >
                              View<span class="sr-only">, <%= canvas.name %></span>
                            </.link>

                            <.link
                              navigate={~p"/dev/canvas-manager/canvases/#{canvas.id}/edit"}
                              class="text-blue-600 hover:text-blue-900"
                            >
                              Edit<span class="sr-only">, <%= canvas.name %></span>
                            </.link>

                            <.link
                              navigate={~p"/canvas/#{canvas.id}"}
                              class="text-green-600 hover:text-green-900"
                              target="_blank"
                            >
                              Open<span class="sr-only">, <%= canvas.name %></span>
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

  defp format_timestamp(%{seconds: seconds} = _timestamp) when is_integer(seconds) do
    {:ok, datetime} = DateTime.from_unix(seconds)
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end

  defp format_timestamp(_timestamp), do: "N/A"
end
