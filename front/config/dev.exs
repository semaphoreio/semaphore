import Config

config :front, :environment, :dev

config :front, FrontWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "build.js",
      cd: Path.expand("../assets", __DIR__),
      env: %{"ESBUILD_LOG_LEVEL" => "silent", "ESBUILD_WATCH" => "1"}
    ]
  ],
  live_reload: [
    patterns: [
      ~r{priv/static/assets/.*(js|css)$},
      ~r{priv/static/assets/.*(png|jpeg|jpg|gif|svg)$},
      ~r{lib/front_web/views/.*(ex)$},
      ~r{lib/front_web/templates/.*(eex)$},
      ~r{assets/js/.*(ts|tsx|js)$}
    ],
    web_console_logger: true
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :front,
  cookie_name: "_semaphoreappdotcom_dev_session"

config :front, domain: System.get_env("BASE_DOMAIN") || "semaphoredev.dev"
config :front, me_host: nil, me_path: "/me"
config :front, docs_domain: "docs.semaphoredev.dev"
config :front, guard_grpc_timeout: 1_000
config :front, permission_patrol_timeout: 1_000
config :front, :connect_github_app_url, "http://localhost:4004/github_app_manifest"

# Support Client tokens
config :front,
  support_app_id: "du8TzC9z2pBIrojNZo10I232e5vsD69O",
  support_app_secret: "d27Yd4IrbHcJ1jmz1QDrGjx3ji7COoJq"

config :front, :artifact_host, "http://localhost:9000"
