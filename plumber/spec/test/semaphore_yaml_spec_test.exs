defmodule SemaphoreYamlSpecTest do
  use ExUnit.Case

  alias IO.ANSI
  alias SemaphoreYamlSpec.Validator

  test "all pipelines in 'pipelines' directory" do
    ppl_dir = "test/pipelines/"

    ppl_dir
    |> File.ls!
    |> Enum.map(&validate_spec(&1, ppl_dir))
  end

  def validate_spec(p, ppl_dir) do
    ANSI.format([:blue, "\nPipeline :", :yellow, " #{p}"]) |> IO.puts

    response = Validator.validate(ppl_dir <> p)
    expected_status = p |> String.ends_with?(".fail.yml") |> expected_status()
    TestHelper.assert_validate(response, expected_status)
  end

  defp expected_status(_contains_fail = true),  do: :error
  defp expected_status(_contains_fail = false), do: :ok
end
