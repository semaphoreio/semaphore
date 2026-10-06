defmodule FrontWeb.Plug.OAuthFlash do
  @moduledoc """
  Renders the outcome of a repository-provider OAuth connect as a flash.

  guard appends `status` (and `code` on failure) to whatever `redirect_path`
  started the connect, and that path is chosen by the caller: the account page,
  the repository chooser, a fork, or - via `FrontWeb.ErrorView.connect_with/2` -
  whichever page the user happened to be on. Only the account page used to read
  those params, so every other entry point bounced the user back with no
  explanation. Reading them here covers all of them at once.
  """

  import Phoenix.Controller, only: [put_flash: 3]

  alias FrontWeb.OAuthFlashMessage

  def init(options), do: options

  def call(conn = %Plug.Conn{params: %{"status" => "success"}}, _opts),
    do: put_flash(conn, :notice, OAuthFlashMessage.success())

  def call(conn = %Plug.Conn{params: %{"status" => "error", "code" => code}}, _opts),
    do: put_flash(conn, :alert, OAuthFlashMessage.error(code))

  def call(conn = %Plug.Conn{params: %{"status" => "error"}}, _opts),
    do: put_flash(conn, :alert, OAuthFlashMessage.generic())

  def call(conn, _opts), do: conn
end
