defmodule PublicAPI.Plugs.FeatureFlag do
  @behaviour Plug
  @moduledoc """
  Plug for checking feature flags.
  """

  alias Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    feature = Keyword.get(opts, :feature)

    message =
      Keyword.get(
        opts,
        :message,
        "Feature is not enabled. Please contact support for more information."
      )

    org_id = conn.assigns[:organization_id]

    exceptions = Keyword.get(opts, :except, [])

    with true <- conn.request_path not in exceptions,
         false <- FeatureProvider.feature_enabled?(feature, param: org_id) do
      PublicAPI.Util.ToTuple.not_found_error(message)
      |> PublicAPI.Util.Response.respond(conn)
      |> Conn.halt()
    else
      _ ->
        conn
    end
  end
end
