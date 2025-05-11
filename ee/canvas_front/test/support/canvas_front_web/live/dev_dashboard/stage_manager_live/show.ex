defmodule CanvasFrontWeb.DevDashboard.StageManagerLive.Show do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case CanvasFront.Stores.Stage.get(%{id: id}) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Stage not found")
         |> redirect(to: ~p"/dev/canvas-manager/stages")}

      stage ->
        # Get the canvas for this stage
        canvas =
          case CanvasFront.Stores.Canvas.get(%{id: stage.canvas_id}) do
            nil -> nil
            canvas -> canvas
          end

        # Extract connections for display
        connections = Map.get(stage, :connections) || []

        {:ok,
         socket
         |> assign(:stage, stage)
         |> assign(:canvas, canvas)
         |> assign(:connections, connections)
         |> assign(:page_title, "Stage: #{stage.name}")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    # Fetch stage events and add them to socket assigns
    stage_id = socket.assigns.stage.id
    stage_events = Support.Stubs.Delivery.list_stage_events(%{stage_id: stage_id}).events || []
    
    {:noreply, socket |> assign(:stage_events, stage_events)}
  end

  @impl true
  def handle_event("delete", _, socket) do
    id = socket.assigns.stage.id
    canvas_id = socket.assigns.stage.canvas_id

    # Delete the stage through the services layer
    case Support.Stubs.Delivery.delete_stage(id) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Stage deleted successfully")
         |> redirect(to: ~p"/dev/canvas-manager/canvases/#{canvas_id}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error deleting stage: #{reason}")}
    end
  end

  @impl true
  def handle_event("seed-event", _params, socket) do
    stage_id = socket.assigns.stage.id
    
    # Create a new stage event with default values
    Support.Stubs.Delivery.seed_event_for_stage(%{stage_id: stage_id})
    
    # Refresh the list of events
    stage_events = Support.Stubs.Delivery.list_stage_events(%{stage_id: stage_id}).events || []
    
    {:noreply, 
     socket
     |> put_flash(:info, "Event added successfully")
     |> assign(:stage_events, stage_events)
    }
  end
  
  @impl true
  def handle_event("seed-approval-event", _params, socket) do
    stage_id = socket.assigns.stage.id
    
    # Create a new approval event
    Support.Stubs.Delivery.seed_event_for_stage(%{
      stage_id: stage_id,
      source_id: "github-event-#{UUID.uuid4()}",
      source_type: :TYPE_EVENT_SOURCE,
      state: :STATE_WAITING,
      state_reason: :STATE_REASON_APPROVAL
    })
    
    # Refresh the list of events
    stage_events = Support.Stubs.Delivery.list_stage_events(%{stage_id: stage_id}).events || []
    
    {:noreply, 
     socket
     |> put_flash(:info, "Approval event added successfully")
     |> assign(:stage_events, stage_events)
    }
  end
  
  @impl true
  def handle_event("delete-connection", %{"index" => index}, socket) do
    index = String.to_integer(index)
    stage = socket.assigns.stage
    connections = stage.connections || []

    if index >= 0 and index < length(connections) do
      # Remove the connection at the specified index
      updated_connections = List.delete_at(connections, index)

      # Update the stage with the new connections list
      case Support.Stubs.Delivery.update_stage(%{
             id: stage.id,
             connections: updated_connections
           }) do
        %{id: _id} = _updated_stage ->
          {:noreply,
           socket
           |> put_flash(:info, "Connection removed successfully")
           |> assign(:connections, updated_connections)}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error removing connection: #{reason}")}

        _ ->
          {:noreply,
           socket
           |> put_flash(:error, "Error removing connection")}
      end
    else
      {:noreply,
       socket
       |> put_flash(:error, "Invalid connection index")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold">Stage Details</h1>
        <div class="flex space-x-3">
          <.link
            navigate={~p"/dev/canvas-manager/stages/#{@stage.id}/edit"}
            class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-pencil" class="h-4 w-4 mr-2" /> Edit Stage
          </.link>
          <button
            phx-click="delete"
            phx-disable-with="Deleting..."
            data-confirm="Are you sure you want to delete this stage? This action cannot be undone."
            class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
          >
            <.icon name="hero-trash" class="h-4 w-4 mr-2" /> Delete Stage
          </button>
        </div>
      </div>

      <div class="bg-white shadow overflow-hidden sm:rounded-lg mb-8">
        <div class="px-4 py-5 sm:px-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">Stage Information</h3>
          <p class="mt-1 max-w-2xl text-sm text-gray-500">Stage details and properties.</p>
        </div>
        <div class="border-t border-gray-200 px-4 py-5 sm:p-0">
          <dl class="sm:divide-y sm:divide-gray-200">
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Name</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{@stage.name}</dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">ID</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">{@stage.id}</dd>
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
                  {@stage.canvas_id} (Canvas not found)
                <% end %>
              </dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Type</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                {@stage[:type] || "Default"}
              </dd>
            </div>
            <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Position</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                {format_position(@stage[:position])}
              </dd>
            </div>
          </dl>
        </div>
      </div>
      
    <!-- Connections -->
      <div class="mb-8">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold">Connections</h2>
          <.link
            navigate={~p"/dev/canvas-manager/connections/new?stage_id=#{@stage.id}"}
            class="inline-flex items-center px-3 py-1.5 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <.icon name="hero-plus" class="h-4 w-4 mr-1" /> Add Connection
          </.link>
        </div>

        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <%= if Enum.empty?(@connections) do %>
            <div class="p-6 text-center text-gray-500">
              No connections are defined for this stage.
            </div>
          <% else %>
            <ul class="divide-y divide-gray-200">
              <%= for {connection, index} <- Enum.with_index(@connections) do %>
                <li class="px-6 py-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <h3 class="text-sm font-medium text-gray-900">{connection.name}</h3>
                      <p class="text-xs text-gray-500">
                        Type:
                        <%= case connection.type do %>
                          <% :TYPE_EVENT_SOURCE -> %>
                            <span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
                              Event Source
                            </span>
                          <% :TYPE_STAGE -> %>
                            <span class="px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-800">
                              Stage
                            </span>
                          <% _ -> %>
                            <span class="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800">
                              {connection.type}
                            </span>
                        <% end %>
                      </p>
                      <p class="text-xs text-gray-500 mt-1">
                        Filter Operator:
                        <%= case connection.filter_operator do %>
                          <% :FILTER_OPERATOR_AND -> %>
                            <span class="font-semibold">AND</span>
                          <% :FILTER_OPERATOR_OR -> %>
                            <span class="font-semibold">OR</span>
                          <% _ -> %>
                            {connection.filter_operator}
                        <% end %>
                        <span class="ml-2">
                          Filters: {length(connection.filters)}
                        </span>
                      </p>
                    </div>
                    <button
                      phx-click="delete-connection"
                      phx-value-index={index}
                      phx-disable-with="Deleting..."
                      data-confirm="Are you sure you want to delete this connection? This action cannot be undone."
                      class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                    >
                      <.icon name="hero-trash" class="h-4 w-4 mr-2" /> Delete Connection
                    </button>
                  </div>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>
      
      <!-- Stage Events Section -->
      <div class="mb-8">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold">Stage Events</h2>
          <div class="flex space-x-2">
            <button
              phx-click="seed-event"
              class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <.icon name="hero-plus" class="h-4 w-4 mr-1" /> Add Default Event
            </button>
            <button
              phx-click="seed-approval-event"
              class="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <.icon name="hero-document-check" class="h-4 w-4 mr-1" /> Add Approval Event
            </button>
          </div>
        </div>

        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <%= if Enum.empty?(@stage_events) do %>
            <div class="p-6 text-center text-gray-500">
              No events are available for this stage.
            </div>
          <% else %>
            <ul class="divide-y divide-gray-200">
              <%= for event <- @stage_events do %>
                <li class="px-6 py-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <h3 class="text-sm font-medium text-gray-900">Event <%= event.id %></h3>
                      <div class="flex flex-wrap gap-2 mt-1">
                        <p class="text-xs text-gray-500">
                          Source Type:
                          <%= case event.source_type do %>
                            <% :TYPE_EVENT_SOURCE -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">
                                Event Source
                              </span>
                            <% :TYPE_STAGE -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-800">
                                Stage Output
                              </span>
                            <% _ -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800">
                                <%= event.source_type %>
                              </span>
                          <% end %>
                        </p>
                        <p class="text-xs text-gray-500">
                          State:
                          <%= case event.state do %>
                            <% :STATE_PENDING -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-yellow-100 text-yellow-800">Pending</span>
                            <% :STATE_WAITING -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-orange-100 text-orange-800">Waiting</span>
                            <% :STATE_PROCESSED -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-green-100 text-green-800">Processed</span>
                            <% _ -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800"><%= event.state %></span>
                          <% end %>
                        </p>
                        <p class="text-xs text-gray-500">
                          Reason:
                          <%= case event.state_reason do %>
                            <% :STATE_REASON_APPROVAL -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-purple-100 text-purple-800">Approval</span>
                            <% :STATE_REASON_TIME_WINDOW -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800">Time Window</span>
                            <% _ -> %>
                              <span class="px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800">Unknown</span>
                          <% end %>
                        </p>
                      </div>
                      <% approval_count = length(event.approvals || []) %>
                      <%= if event.state == :STATE_WAITING && event.state_reason == :STATE_REASON_APPROVAL do %>
                        <p class="text-xs text-gray-600 mt-1">
                          Approvals: <%= approval_count %> required
                        </p>
                      <% end %>
                      <p class="text-xs text-gray-500 mt-1">ID: <%= event.id %></p>
                    </div>
                  </div>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>
      </div>

      <div class="mt-8 flex space-x-4">
        <.link
          navigate={~p"/dev/canvas-manager/stages"}
          class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
        >
          <.icon name="hero-arrow-left" class="h-4 w-4 mr-2" /> Back to Stages
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
