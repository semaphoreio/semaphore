defmodule FrontWeb.Endpoint do
  use Sentry.PlugCapture

  use Phoenix.Endpoint, otp_app: :front

  plug(
    Plug.Static,
    at: "/projects",
    from: :front,
    gzip: false,
    only: ~w(assets)
  )

  plug(
    Plug.Static,
    at: "/",
    from: :front,
    gzip: false,
    only: ~w(robots.txt)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(FrontWeb.Plugs.RequestLogger)
  plug(FrontWeb.Plugs.Metrics)

  plug(
    Plug.Parsers,
    parsers: [{:urlencoded, length: 10_000_000}, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(Sentry.PlugContext)

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # Add ETag support for all GET requests (disabled in test environment)
  # Uses ConditionalETag to skip chunked responses
  if Mix.env() != :test do
    plug(FrontWeb.Plugs.ConditionalETag,
      generator: ETag.Generator.SHA1,
      methods: ["GET"],
      status_codes: [200]
    )
  end

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug(
    Plug.Session,
    store: :cookie,
    key: "_projecct_page_key",
    secure: true,
    signing_salt: {FrontWeb.Endpoint, :signing_salt, []}
  )

  plug(FrontWeb.Router)

  @doc """
  Callback invoked for dynamically configuring the endpoint.

  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"

      http_config =
        if Keyword.get(config, :http) do
          config |> Keyword.get(:http) |> Keyword.put(:port, port)
        else
          [:inet6, port: port]
        end

      {:ok, Keyword.put(config, :http, http_config)}
    else
      {:ok, config}
    end
  end

  def signing_salt, do: Application.get_env(:front, :signing_salt)
end
