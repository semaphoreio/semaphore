defmodule CanvasFrontWeb.DevDashboard.ConnectionManagerLive.New do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    # Get the stage we're adding a connection to
    stage_id = params["stage_id"]

    case CanvasFront.Stores.Stage.get(%{id: stage_id}) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Stage not found")
         |> redirect(to: ~p"/dev/canvas-manager/stages")}

      stage ->
        canvas_id = stage.canvas_id

        # Get all available stages and event sources from the same canvas
        stages =
          CanvasFront.Stores.Stage.list(%{canvas_id: canvas_id})
          |> Enum.filter(fn s -> s.id != stage_id end)

        event_sources =
          CanvasFront.Stores.EventSource.list(%{canvas_id: canvas_id})

        {:ok,
         socket
         |> assign(:page_title, "New Connection")
         |> assign(:stage, stage)
         |> assign(:available_stages, stages)
         |> assign(:available_event_sources, event_sources)
         |> assign(:selected_type, :TYPE_EVENT_SOURCE)
         |> assign(:selected_target, nil)
         |> assign(:filter_operator, :FILTER_OPERATOR_AND)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("type-changed", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:selected_type, String.to_existing_atom(type))
     |> assign(:selected_target, nil)}
  end

  @impl true
  def handle_event("target-changed", %{"target" => target}, socket) do
    {:noreply, assign(socket, :selected_target, target)}
  end

  @impl true
  def handle_event("operator-changed", %{"operator" => operator}, socket) do
    {:noreply, assign(socket, :filter_operator, String.to_existing_atom(operator))}
  end

  @impl true
  def handle_event("save", _params, socket) do
    %{
      stage: stage,
      selected_type: type,
      selected_target: target,
      filter_operator: operator
    } = socket.assigns

    if is_nil(target) do
      {:noreply,
       socket
       |> put_flash(:error, "Please select a target")}
    else
      # Get the current connections and add the new one
      current_connections = stage.connections || []

      # Find the target name based on the selected ID
      target_name =
        case type do
          :TYPE_STAGE ->
            stage = Enum.find(socket.assigns.available_stages, fn s -> s.id == target end)
            if stage, do: stage.name, else: target

          :TYPE_EVENT_SOURCE ->
            event_source =
              Enum.find(socket.assigns.available_event_sources, fn es -> es.id == target end)

            if event_source, do: event_source.name, else: target
        end

      new_connection = %{
        type: type,
        name: target_name,
        filters: [],
        filter_operator: operator
      }

      updated_connections = current_connections ++ [new_connection]

      # Update the stage with the new connection
      case CanvasFront.Stores.Stage.update(%{
             id: stage.id,
             connections: updated_connections
           }) do
        {:ok, stage} ->
          {:noreply,
           socket
           |> put_flash(:info, "Connection added successfully!")
           |> redirect(to: ~p"/dev/canvas-manager/stages/#{stage.id}")}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Error adding connection: #{reason}")}

        _ ->
          {:noreply,
           socket
           |> put_flash(:error, "Error adding connection")}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">Add Connection to Stage</h1>
        <p class="mt-2 text-sm text-gray-600">
          Connect stage "{@stage.name}" to another stage or event source
        </p>
      </div>

      <div class="bg-white shadow sm:rounded-md p-6">
        <form phx-submit="save">
          <div class="space-y-6">
            <div>
              <label class="block text-sm font-medium text-gray-700">Connection Type</label>
              <div class="mt-2">
                <div class="flex items-center space-x-4">
                  <div class="flex items-center">
                    <input
                      id="type-event-source"
                      name="type"
                      type="radio"
                      value="TYPE_EVENT_SOURCE"
                      checked={@selected_type == :TYPE_EVENT_SOURCE}
                      phx-change="type-changed"
                      class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <label for="type-event-source" class="ml-2 block text-sm text-gray-700">
                      Event Source
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      id="type-stage"
                      name="type"
                      type="radio"
                      value="TYPE_STAGE"
                      checked={@selected_type == :TYPE_STAGE}
                      phx-change="type-changed"
                      class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <label for="type-stage" class="ml-2 block text-sm text-gray-700">
                      Stage
                    </label>
                  </div>
                </div>
              </div>
            </div>

            <div>
              <label for="target" class="block text-sm font-medium text-gray-700">
                <%= if @selected_type == :TYPE_EVENT_SOURCE do %>
                  Select Event Source
                <% else %>
                  Select Stage
                <% end %>
              </label>
              <div class="mt-1">
                <select
                  id="target"
                  name="target"
                  phx-change="target-changed"
                  class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
                  required
                >
                  <option value="" selected={is_nil(@selected_target)}>
                    -- Select a {if @selected_type == :TYPE_EVENT_SOURCE,
                      do: "Event Source",
                      else: "Stage"} --
                  </option>
                  <%= if @selected_type == :TYPE_EVENT_SOURCE do %>
                    <%= if Enum.empty?(@available_event_sources) do %>
                      <option disabled>No event sources available</option>
                    <% else %>
                      <%= for event_source <- @available_event_sources do %>
                        <option value={event_source.id} selected={@selected_target == event_source.id}>
                          {event_source.name}
                        </option>
                      <% end %>
                    <% end %>
                  <% else %>
                    <%= if Enum.empty?(@available_stages) do %>
                      <option disabled>No other stages available</option>
                    <% else %>
                      <%= for stage <- @available_stages do %>
                        <option value={stage.id} selected={@selected_target == stage.id}>
                          {stage.name}
                        </option>
                      <% end %>
                    <% end %>
                  <% end %>
                </select>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700">Filter Operator</label>
              <div class="mt-2">
                <div class="flex items-center space-x-4">
                  <div class="flex items-center">
                    <input
                      id="operator-and"
                      name="operator"
                      type="radio"
                      value="FILTER_OPERATOR_AND"
                      checked={@filter_operator == :FILTER_OPERATOR_AND}
                      phx-change="operator-changed"
                      class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <label for="operator-and" class="ml-2 block text-sm text-gray-700">
                      AND
                    </label>
                  </div>
                  <div class="flex items-center">
                    <input
                      id="operator-or"
                      name="operator"
                      type="radio"
                      value="FILTER_OPERATOR_OR"
                      checked={@filter_operator == :FILTER_OPERATOR_OR}
                      phx-change="operator-changed"
                      class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                    <label for="operator-or" class="ml-2 block text-sm text-gray-700">
                      OR
                    </label>
                  </div>
                </div>
              </div>
              <p class="mt-1 text-sm text-gray-500">
                How filters should be combined (defaults to AND).
              </p>
            </div>

            <div class="flex justify-end space-x-3 pt-5">
              <.link
                navigate={~p"/dev/canvas-manager/stages/#{@stage.id}"}
                class="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Add Connection
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
