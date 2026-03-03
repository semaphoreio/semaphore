formatters = [ExUnit.CLIFormatter]

formatters =
  System.get_env("CI")
  |> case do
    nil ->
      formatters

    _ ->
      [JUnitFormatter | formatters]
  end

ExUnit.configure(
  exclude: [integration: true],
  capture_log: true,
  formatters: formatters
)

# Look at @timestamp in Support.Factories.Job module.
# IEx.Helpers.r(Support.Factories.Job)

ExUnit.start()
