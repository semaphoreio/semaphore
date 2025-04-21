defmodule CanvasFrontWeb.DevDashboard.DashboardLive.Index do
  use CanvasFrontWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Canvas Development Dashboard")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-6xl px-4 sm:px-6 lg:px-8 py-10">
      <h1 class="text-3xl font-bold mb-8">Canvas Development Dashboard</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.dashboard_card
          title="Canvases"
          description="Create and manage canvases"
          icon="hero-document-text"
          to={~p"/dev/canvas-manager/canvases"}
        />

        <.dashboard_card
          title="Stages"
          description="Create and manage stages"
          icon="hero-cube"
          to={~p"/dev/canvas-manager/stages"}
        />

        <.dashboard_card
          title="Event Sources"
          description="Create and manage event sources"
          icon="hero-arrow-path"
          to={~p"/dev/canvas-manager/event-sources"}
        />

        <.dashboard_card
          title="Seed Data"
          description="Initialize with predefined data"
          icon="hero-document-plus"
          to={~p"/dev/canvas-manager/seed"}
        />
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :icon, :string, required: true
  attr :to, :string, required: true

  def dashboard_card(assigns) do
    ~H"""
    <.link navigate={@to} class="block bg-white shadow rounded-lg hover:shadow-md transition">
      <div class="p-6">
        <div class="flex items-center mb-4">
          <div class="bg-blue-100 rounded-full p-3 mr-4">
            <.icon name={@icon} class="h-6 w-6 text-blue-600" />
          </div>
          <h2 class="text-xl font-semibold">{@title}</h2>
        </div>
        <p class="text-gray-600">{@description}</p>
      </div>
    </.link>
    """
  end
end
