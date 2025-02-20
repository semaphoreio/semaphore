formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI", "")
  |> case do
    "" ->
      [ExUnitNotifier | formatters]

    _ ->
      [JUnitFormatter | formatters]
  end

ExUnit.configure(formatters: formatters)
ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(RepositoryHub.Repo, :manual)
