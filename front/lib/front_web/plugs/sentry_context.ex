defmodule FrontWeb.Plug.SentryContext do
  def init(options), do: options

  def call(conn, _opts) do
    Sentry.Context.set_user_context(%{
      id: conn.assigns.user_id,
      org_id: conn.assigns.organization_id
    })

    conn
  end
end
