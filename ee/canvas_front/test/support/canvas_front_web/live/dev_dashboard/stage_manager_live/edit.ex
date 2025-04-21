defmodule CanvasFrontWeb.DevDashboard.StageManagerLive.Edit do
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
        # Extract position for form fields
        position = stage[:position] || %{x: 0, y: 0}

        # Get all canvases for the dropdown
        canvases = Support.Stubs.Delivery.list_canvases()

        {:ok,
         socket
         |> assign(:stage, stage)
         |> assign(:canvases, canvases)
         |> assign(:position_x, position.x)
         |> assign(:position_y, position.y)
         |> assign(:page_title, "Edit Stage: #{stage.name}")}
    end
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

    # Update stage through the direct store
    update_attrs = %{
      id: socket.assigns.stage.id,
      name: stage_params["name"],
      canvas_id: stage_params["canvas_id"],
      position: position,
      type: stage_params["type"]
    }

    case Support.Stubs.Delivery.update_stage(update_attrs) do
      %{id: id} = _stage ->
        {:noreply,
         socket
         |> put_flash(:info, "Stage updated successfully!")
         |> redirect(to: ~p"/dev/canvas-manager/stages/#{id}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Error updating stage")
         |> assign(
           :stage,
           Map.merge(socket.assigns.stage, %{
             name: stage_params["name"],
             canvas_id: stage_params["canvas_id"],
             type: stage_params["type"]
           })
         )
         |> assign(:position_x, position.x)
         |> assign(:position_y, position.y)}
    end
  end

  def handle_event("validate", %{"stage" => stage_params}, socket) do
    # Update the form with the validated params
    {:noreply,
     socket
     |> assign(
       :stage,
       Map.merge(socket.assigns.stage, %{
         name: stage_params["name"],
         canvas_id: stage_params["canvas_id"],
         type: stage_params["type"]
       })
     )
     |> assign(:position_x, parse_int(stage_params["position_x"]))
     |> assign(:position_y, parse_int(stage_params["position_y"]))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">Edit Stage</h1>
        <p class="mt-2 text-sm text-gray-600">
          Update stage information
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
                Stage ID: {@stage.id} (cannot be changed)
              </p>
            </div>
          </div>

          <div class="flex justify-end space-x-3">
            <.link
              navigate={~p"/dev/canvas-manager/stages/#{@stage.id}"}
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
