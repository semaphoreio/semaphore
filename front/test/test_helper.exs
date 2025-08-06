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

Support.Stubs.init()

Mox.defmock(ServiceAccountMock, for: Front.ServiceAccount.Behaviour)

ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(trace: false, capture_log: true)

Faker.start()
