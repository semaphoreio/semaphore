ExUnit.configure(
  capture_log: true,
  formatters: [JUnitFormatter, ExUnit.CLIFormatter],
  trace: true
)

ExUnit.start()

if System.get_env("START_WALLABY") do
  # Start Wallaby and configure it
  {:ok, _} = Application.ensure_all_started(:wallaby)

  # Ensure screenshots directory exists
  screenshots_dir = System.get_env("WALLABY_SCREENSHOTS") || "./out"
  File.mkdir_p!(screenshots_dir)
end
