defmodule FrontWeb.CiAssistantController do
  use FrontWeb, :controller

  plug(FrontWeb.Plugs.FetchPermissions, scope: "org")
  plug(FrontWeb.Plugs.PageAccess, permissions: "organization.view")
  plug(FrontWeb.Plugs.Header)
  plug(:put_layout, :organization)

  def index(conn, _params) do
    render(conn, "index.html", js: :ciAssistant)
  end
end
