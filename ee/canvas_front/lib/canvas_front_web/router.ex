defmodule CanvasFrontWeb.Router do
  use CanvasFrontWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CanvasFrontWeb.Layouts, :root}

    if Application.compile_env(:canvas_front, :environment) == :prod do
      plug(Plug.SSL,
        rewrite_on: [:x_forwarded_proto],
        expires: 63_072_000,
        subdomains: true,
        preload: true
      )
    end

    plug :protect_from_forgery
    plug :put_secure_browser_headers

    if Enum.member?([:dev, :test], Application.compile_env(:canvas_front, :environment)) do
      plug(FrontWeb.Plug.DevelopmentHeaders)
    end

    plug(CanvasFrontWeb.Plug.AssignUserInfo)
    plug(CanvasFrontWeb.Plug.AssignOrgInfo)
    plug(CanvasFrontWeb.Plugs.FetchPermissions, scope: "org")
    plug(CanvasFrontWeb.Plugs.PageAccess, permissions: "organization.view")
    plug(CanvasFrontWeb.Plugs.FeatureEnabled, [:experimental_canvas_ui])
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CanvasFrontWeb do
    pipe_through :browser

    live "/canvas/:canvas_id", CanvasLive, :show
  end

  # Other scopes may use custom stacks.
  # scope "/api", CanvasFrontWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:canvas_front, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CanvasFrontWeb.Telemetry

      # Canvas Development Dashboard routes
      scope "/canvas-manager", CanvasFrontWeb.DevDashboard do
        live "/", DashboardLive.Index, :index
        live "/canvases", CanvasManagerLive.Index, :index
        live "/canvases/new", CanvasManagerLive.New, :new
        live "/canvases/:id", CanvasManagerLive.Show, :show
        live "/canvases/:id/edit", CanvasManagerLive.Edit, :edit

        live "/stages", StageManagerLive.Index, :index
        live "/stages/new", StageManagerLive.New, :new
        live "/stages/:id", StageManagerLive.Show, :show
        live "/stages/:id/edit", StageManagerLive.Edit, :edit

        live "/connections/new", ConnectionManagerLive.New, :new

        live "/event-sources", EventSourceManagerLive.Index, :index
        live "/event-sources/new", EventSourceManagerLive.New, :new
        live "/event-sources/:id", EventSourceManagerLive.Show, :show
        live "/event-sources/:id/edit", EventSourceManagerLive.Edit, :edit

        live "/seed", SeedDataLive, :index
      end
    end
  end
end
