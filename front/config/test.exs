import Config

config :front, :environment, :test

config :front, FrontWeb.Endpoint,
  url: [host: "localhost"],
  http: [port: 4001],
  server: true

config :logger, :console,
  level: :info,
  format: {Support.Logger, :format},
  metadata: [:file, :line, :inspect]

# Internal API endpoints configuration removed - now handled in runtime.exs

config :front,
  domain: "semaphoretest.test",
  docs_domain: "docs.semaphoretest.test",
  start_reactor: true

config :wallaby, screenshot_dir: System.get_env("WALLABY_SCREENSHOTS") || "./out"
config :wallaby, screenshot_on_failure: true
config :wallaby, driver: Wallaby.Chrome
config :wallaby, max_wait_time: 10_000

config :wallaby, :chromedriver,
  headless: false,
  capabilities: %{
    javascriptEnabled: true,
    loadImages: true,
    version: "",
    rotatable: false,
    takesScreenshot: true,
    cssSelectorsEnabled: true,
    nativeEvents: false,
    platform: "ANY",
    unhandledPromptBehavior: "accept",
    loggingPrefs: %{
      browser: "DEBUG"
    },
    chromeOptions: %{
      args: [
        "--headless=new",
        "--no-sandbox",
        "window-size=1920,1080",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--disable-background-networking",
        "--disable-renderer-backgrounding",
        "--disable-software-rasterizer",
        "--remote-debugging-port=0",
        "--user-agent=Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
      ]
    }
  }

config :joken, current_time_adapter: Support.TimeMock

config :front, guard_grpc_timeout: 1_000
config :front, permission_patrol_timeout: 1_000

config :junit_formatter,
  automatic_create_dir?: true,
  report_dir: "./out",
  report_file: "test-reports.xml",
  print_report_file: true,
  include_filename?: true,
  include_file_line?: true

config :front, me_host: "me.", me_path: "/"
config :front, :artifact_host, "http://localhost:9000"
