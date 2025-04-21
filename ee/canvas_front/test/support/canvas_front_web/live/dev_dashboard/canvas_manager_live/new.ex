defmodule CanvasFrontWeb.DevDashboard.CanvasManagerLive.New do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New Canvas")
     |> assign(:canvas, %{
       name: "",
       organization_id: "org-" <> random_id(),
       requester_id: "user-" <> random_id()
     })}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"canvas" => canvas_params}, socket) do
    # Create new canvas through the stub server
    case Support.Stubs.Delivery.seed_canvas(%{
           name: canvas_params["name"],
           organization_id: canvas_params["organization_id"],
           created_by: canvas_params["requester_id"]
         }) do
      %{id: id} ->
        {:noreply,
         socket
         |> put_flash(:info, "Canvas created successfully!")
         |> redirect(to: ~p"/dev/canvas-manager/canvases/#{id}")}

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Error creating canvas")
         |> assign(:canvas, canvas_params)}
    end
  end

  def handle_event("validate", %{"canvas" => canvas_params}, socket) do
    {:noreply, assign(socket, :canvas, canvas_params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold">New Canvas</h1>
        <p class="mt-2 text-sm text-gray-600">
          Create a new canvas for development
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
                value={@canvas["name"] || @canvas.name}
                required
              />
            </div>

            <div class="sm:col-span-6">
              <.input
                field={f[:organization_id]}
                type="text"
                label="Organization ID"
                value={@canvas["organization_id"] || @canvas.organization_id}
                required
              />
            </div>

            <div class="sm:col-span-6">
              <.input
                field={f[:requester_id]}
                type="text"
                label="Requester/Creator ID"
                value={@canvas["requester_id"] || @canvas.requester_id}
                required
              />
            </div>
          </div>

          <div class="flex justify-end space-x-3">
            <.link
              navigate={~p"/dev/canvas-manager/canvases"}
              class="px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Cancel
            </.link>
            <.button type="submit" phx-disable-with="Creating...">
              Create Canvas
            </.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  defp random_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end
end
