defmodule CanvasFrontWeb.DevDashboard.SeedDataLive do
  use CanvasFrontWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    stats = get_stats()

    {:ok,
     socket
     |> assign(:page_title, "Seed Test Data")
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_event("seed-default-data", _params, socket) do
    # Seed default data through the services layer
    Support.Stubs.Delivery.seed_default_data()
    stats = get_stats()

    {:noreply,
     socket
     |> put_flash(:info, "Default data seeded successfully")
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_event("clear-all-data", _params, socket) do
    # Clear data through the services layer
    Support.Stubs.Delivery.clear_mock_data()
    stats = get_stats()

    {:noreply,
     socket
     |> put_flash(:info, "All data cleared successfully")
     |> assign(:stats, stats)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">Seed Test Data</h1>
        <p class="mt-2 text-sm text-gray-600">
          Initialize the database with predefined test data for development
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div class="bg-white shadow rounded-lg p-6">
          <div class="flex items-center">
            <div class="bg-blue-100 rounded-full p-3 mr-4">
              <.icon name="hero-document-text" class="h-6 w-6 text-blue-600" />
            </div>
            <div>
              <h2 class="text-xl font-semibold">Canvases</h2>
              <p class="text-3xl font-bold mt-1">{@stats.canvas_count}</p>
            </div>
          </div>
        </div>

        <div class="bg-white shadow rounded-lg p-6">
          <div class="flex items-center">
            <div class="bg-blue-100 rounded-full p-3 mr-4">
              <.icon name="hero-cube" class="h-6 w-6 text-blue-600" />
            </div>
            <div>
              <h2 class="text-xl font-semibold">Stages</h2>
              <p class="text-3xl font-bold mt-1">{@stats.stage_count}</p>
            </div>
          </div>
        </div>

        <div class="bg-white shadow rounded-lg p-6">
          <div class="flex items-center">
            <div class="bg-blue-100 rounded-full p-3 mr-4">
              <.icon name="hero-arrow-path" class="h-6 w-6 text-blue-600" />
            </div>
            <div>
              <h2 class="text-xl font-semibold">Event Sources</h2>
              <p class="text-3xl font-bold mt-1">{@stats.event_source_count}</p>
            </div>
          </div>
        </div>
      </div>

      <div class="bg-white shadow rounded-lg p-6 mb-8">
        <h2 class="text-xl font-semibold mb-4">Seed Operations</h2>
        <div class="space-y-6">
          <div>
            <h3 class="text-md font-medium mb-2">Default Test Data</h3>
            <p class="text-sm text-gray-600 mb-4">
              Seed the database with a default set of test data, including canvases, stages, and event sources.
            </p>
            <button
              phx-click="seed-default-data"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              data-confirm="This will reset existing data and add new test data. Proceed?"
            >
              <.icon name="hero-document-plus" class="h-4 w-4 mr-2" /> Seed Default Data
            </button>
          </div>

          <div class="pt-6 border-t border-gray-200">
            <h3 class="text-md font-medium mb-2">Clear All Data</h3>
            <p class="text-sm text-gray-600 mb-4">
              Delete all data from the database, including canvases, stages, and event sources.
            </p>
            <button
              phx-click="clear-all-data"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
              data-confirm="This will delete ALL data in the database. This action cannot be undone. Are you sure?"
            >
              <.icon name="hero-trash" class="h-4 w-4 mr-2" /> Clear All Data
            </button>
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

  # Helper to get current database stats
  defp get_stats do
    %{
      canvas_count: get_table_count(:canvas),
      stage_count: get_table_count(:stage),
      event_source_count: get_table_count(:event_source)
    }
  end

  defp get_table_count(table) do
    if Support.Stubs.DB.table_exists?(table) do
      Support.Stubs.DB.all(table) |> length()
    else
      0
    end
  end
end
