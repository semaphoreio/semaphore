ExUnit.configure(
  exclude: [integration: true],
  capture_log: true,
  formatters: [JUnitFormatter, ExUnit.CLIFormatter]
)

Ecto.Adapters.SQL.Sandbox.mode(EphemeralEnvironments.Repo, :manual)
ExUnit.start()
