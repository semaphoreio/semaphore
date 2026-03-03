ExUnit.configure(timeout: :infinity, formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(trace: true, capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Secrethub.Repo, :manual)
