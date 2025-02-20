defmodule FrontWeb.ErrorView do
  use FrontWeb, :view

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end

  def connect_with(conn, :bitbucket), do: connect_with(conn, "bitbucket")
  def connect_with(conn, :github), do: connect_with(conn, "github")
  def connect_with(conn, :gitlab), do: connect_with(conn, "gitlab")

  def connect_with(conn, provider) do
    origin_url = Plug.Conn.request_url(conn)
    domain = Application.get_env(:front, :domain)

    "https://id.#{domain}/oauth/#{provider}?redirect_path=#{origin_url}"
    |> URI.encode()
  end

  def anonymous?(conn) do
    if Map.get(conn.assigns, :anonymous), do: conn.assigns.anonymous == true
  end

  defdelegate login_url(conn), to: FrontWeb.LayoutView
  defdelegate signup_url(conn), to: FrontWeb.LayoutView
end
