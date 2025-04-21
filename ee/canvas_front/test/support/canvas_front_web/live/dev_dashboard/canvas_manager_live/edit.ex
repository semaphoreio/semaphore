defmodule CanvasFrontWeb.DevDashboard.CanvasManagerLive.Edit do
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
        {:ok,
         socket
         |> assign(:canvas, canvas)
         |> assign(:page_title, "Edit Canvas: #{canvas.name}")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"canvas" => canvas_params}, socket) do
    # Update canvas properties using the service layer
    update_attrs = %{
      id: socket.assigns.canvas.id,
      name: canvas_params["name"],
      organization_id: canvas_params["organization_id"],
      created_by: canvas_params["created_by"]
    }

    case Support.Stubs.Delivery.update_canvas(update_attrs) do
      %{id: id} = _canvas ->
        {:noreply,
         socket
         |> put_flash(:info, "Canvas updated successfully!")
         |> redirect(to: ~p"/dev/canvas-manager/canvases/#{id}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Error updating canvas")
         |> assign(:canvas, canvas_params)}
    end
  end

  def handle_event("validate", %{"canvas" => canvas_params}, socket) do
    {:noreply,
     assign(
       socket,
       :canvas,
       Map.merge(
         socket.assigns.canvas,
         Enum.into(canvas_params, %{}, fn {k, v} -> {String.to_atom(k), v} end)
       )
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">Edit Canvas</h1>
        <p class="mt-2 text-sm text-gray-600">
          Update canvas information
        </p>
      </div>

      <.form :let={f} for={%{}} as={:canvas} phx-change="validate" phx-submit="save">
        <div class="space-y-6 bg-white shadow sm:rounded-md p-6">
          <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
            <div class="sm:col-span-6">
              <.input
                field={f[:name]}
                type="text"
                label="Canvas Name"
                value={@canvas[:name] || @canvas.name}
                required
              />
            </div>

            <div class="sm:col-span-6">
              <.input
                field={f[:organization_id]}
                type="text"
                label="Organization ID"
                value={@canvas[:organization_id] || @canvas.organization_id}
                required
              />
            </div>

            <div class="sm:col-span-6">
              <.input
                field={f[:created_by]}
                type="text"
                label="Created By"
                value={@canvas[:created_by] || @canvas.created_by}
                required
              />
            </div>

            <div class="sm:col-span-6">
              <p class="text-sm text-gray-500">
                Canvas ID: {@canvas.id} (cannot be changed)
              </p>
            </div>
          </div>

          <div class="flex justify-end space-x-3">
            <.link
              navigate={~p"/dev/canvas-manager/canvases/#{@canvas.id}"}
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
end
