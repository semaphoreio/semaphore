ExUnit.start(trace: true)

defmodule TestHelper do
  use ExUnit.Case

  @debug? true

  def assert_validate(response, expected_status) do
    if(@debug?, do: response |> IO.inspect(label: " response"))
    assert_validate_(response, expected_status)
  end

  def assert_validate_(response, expected_status) when is_tuple(response), do:
    assert {^expected_status, _} = response
  def assert_validate_(response, expected_status) when is_atom(response), do:
    assert expected_status == response

end
