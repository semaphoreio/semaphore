ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Projecthub.Repo, :manual)
