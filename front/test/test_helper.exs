if System.get_env("CI") == "true" do
  Code.put_compiler_option(:warnings_as_errors, true)
end

#
# Wallaby configuration. Wallaby is a browser based test runner.
#

{:ok, _} = Application.ensure_all_started(:wallaby)

Application.put_env(:wallaby, :base_url, FrontWeb.Endpoint.url())

{:ok, file} = File.open("browser_logs.log", [:write])
Application.put_env(:wallaby, :js_logger, file)

Application.put_env(
  :wallaby,
  :chromedriver,
  Application.get_env(:wallaby, :chromedriver, [])
  |> Keyword.merge(
    headless: false,
    capabilities:
      Wallaby.Chrome.default_capabilities()
      |> put_in([:chromeOptions, :args], [
        "--headless=new",
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--disable-background-networking",
        "--disable-renderer-backgrounding",
        "--disable-software-rasterizer",
        "--remote-debugging-port=0",
        "window-size=1920,1600",
        "--user-agent=Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36"
      ])
  )
)

Support.Stubs.init()

Mox.defmock(ServiceAccountMock, for: Front.ServiceAccount.Behaviour)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])

ExUnit.start(trace: false, capture_log: true)

Faker.start()
