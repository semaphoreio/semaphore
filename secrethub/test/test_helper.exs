ExUnit.configure(formatters: [JUnitFormatter, ExUnit.CLIFormatter])
ExUnit.start(trace: true)

ExUnit.configure(timeout: :infinity)

Ecto.Adapters.SQL.Sandbox.mode(Secrethub.Repo, :manual)
