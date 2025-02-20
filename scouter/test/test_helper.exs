ExUnit.configure(
  capture_log: true,
  formatters: [JUnitFormatter, ExUnit.CLIFormatter]
)

Ecto.Adapters.SQL.Sandbox.mode(Scouter.Repo, :manual)

ExUnit.start()
