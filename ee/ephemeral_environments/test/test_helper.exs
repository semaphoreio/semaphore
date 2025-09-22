formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end


ExUnit.configure(
  exclude: [integration: true],
  capture_log: true,
  formatters: formatters
)

Ecto.Adapters.SQL.Sandbox.mode(EphemeralEnvironments.Repo, :manual)
ExUnit.start()
