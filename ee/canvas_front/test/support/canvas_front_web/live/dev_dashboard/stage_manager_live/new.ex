defmodule CanvasFrontWeb.DevDashboard.StageManagerLive.New do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    canvases = Support.Stubs.Delivery.list_canvases()

    # Initialize with canvas_id from params if available
    canvas_id = params["canvas_id"] || List.first(canvases, %{})[:id]

    {:ok,
     socket
     |> assign(:page_title, "New Stage")
     |> assign(:canvases, canvases)
     |> assign(:stage, %{
       name: "",
       canvas_id: canvas_id,
       position: %{
         x: 100,
         y: 100
       },
       type: "default"
     })}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"stage" => stage_params}, socket) do
    position = %{
      x: parse_int(stage_params["position_x"]),
      y: parse_int(stage_params["position_y"])
    }

    # Create new stage through the stub server
    stage_attrs = %{
      name: stage_params["name"],
      canvas_id: stage_params["canvas_id"],
      position: position,
      type: stage_params["type"]
    }

    case Support.Stubs.Delivery.seed_stage(stage_attrs) do
      %{id: id} = stage ->
        # Dispatch stage creation event
        Support.Events.stage_created(stage.canvas_id, id)
        
        {:noreply,
         socket
         |> put_flash(:info, "Stage created successfully!")
         |> redirect(to: ~p"/dev/canvas-manager/stages/#{id}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Error creating stage")
         |> assign(
           :stage,
           Map.merge(socket.assigns.stage, %{
             name: stage_params["name"],
             canvas_id: stage_params["canvas_id"],
             type: stage_params["type"]
           })
         )}
    end
  end

  def handle_event("validate", %{"stage" => stage_params}, socket) do
    # Update the form with the validated params
    {:noreply,
     assign(
       socket,
       :stage,
       Map.merge(socket.assigns.stage, %{
         name: stage_params["name"],
         canvas_id: stage_params["canvas_id"],
         type: stage_params["type"]
       })
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">New Stage</h1>
        <p class="mt-2 text-sm text-gray-600">
          Create a new stage for a canvas
        </p>
      </div>

      <.form :let={f} for={%{}} as={:stage} phx-change="validate" phx-submit="save">
        <div class="space-y-6 bg-white shadow sm:rounded-md p-6">
          <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
            <div class="sm:col-span-6">
              <.input field={f[:name]} type="text" label="Stage Name" value={@stage.name} required />
            </div>

            <div class="sm:col-span-6">
              <label for="canvas_id" class="block text-sm font-medium text-gray-700">Canvas</label>
              <select
                id="canvas_id"
                name="stage[canvas_id]"
                class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
                required
              >
                <option value="" disabled selected={!@stage.canvas_id}>Select Canvas</option>
                <%= for canvas <- @canvases do %>
                  <option value={canvas.id} selected={@stage.canvas_id == canvas.id}>
                    {canvas.name}
                  </option>
                <% end %>
              </select>
            </div>

            <div class="sm:col-span-6">
              <label for="type" class="block text-sm font-medium text-gray-700">Stage Type</label>
              <select
                id="type"
                name="stage[type]"
                class="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
              >
                <option value="default" selected={@stage.type == "default"}>Default</option>
                <option value="start" selected={@stage.type == "start"}>Start</option>
                <option value="end" selected={@stage.type == "end"}>End</option>
              </select>
            </div>

            <div class="sm:col-span-3">
              <.input
                field={f[:position_x]}
                type="number"
                label="Position X"
                value={@stage.position.x}
                required
              />
            </div>

            <div class="sm:col-span-3">
              <.input
                field={f[:position_y]}
                type="number"
                label="Position Y"
                value={@stage.position.y}
                required
              />
            </div>
          </div>

          <div class="flex justify-end space-x-3">
            <.link
              navigate={~p"/dev/canvas-manager/stages"}
              class="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Cancel
            </.link>
            <.button type="submit" phx-disable-with="Creating...">
              Create Stage
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
