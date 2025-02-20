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
ExUnit.start()

defmodule TestHelper do
  use ExUnit.Case

  def assert_validate(response, expected_status),
    do: assert_validate_(response, expected_status)

  def assert_validate_(response, expected_status) when is_tuple(response),
    do: assert({^expected_status, _} = response)

  def assert_validate_(response, expected_status) when is_atom(response),
    do: assert(expected_status == response)
end
