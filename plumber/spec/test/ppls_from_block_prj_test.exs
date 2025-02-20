defmodule PplsFromBlockPrjTest do
  @moduledoc """
  Run tests on .semaphore.yml files in block project

  Purpose of this test is to make sure that pipeline definitions in
  block project priv dir are still well formed after pipeline specification update
  """

  use ExUnit.Case

  @debug true

  test "all pipelines in 'block' project" do
    exclude_repos = ~w(1_config_file_exists 3_should_fail .fail.yml)
    local_repos = "../block/priv/repos"

    Path.wildcard("#{local_repos}/*/.semaphore/*.yml", match_dot: true)
    |> log(" Pipelines")
    |> assert_pipeline_repos_exist()
    |> Enum.filter(fn ppl -> not contains_any_substring?(ppl, exclude_repos) end)
    |> log(" Pipelines filtered")
    |> Enum.map(fn ppl ->
      log(ppl, "\nPipeline")
      SemaphoreYamlSpec.Validator.validate(ppl) |> log("Validation response")
      |> TestHelper.assert_validate(:ok)
    end)
  end

  defp assert_pipeline_repos_exist(pipeline_repos) do
    assert length(pipeline_repos) > 0
    pipeline_repos
  end

  defp contains_any_substring?(string, list_of_substrings) do
    list_of_substrings
    |> Enum.map(fn substring -> String.contains?(string, substring) end)
    |> Enum.any?()
  end

  defp log(value, label),                   do: log_(@debug, value, label)
  defp log_(_debug = false, value, _label), do: value
  defp log_(_debug = true, value, label) do
    import IO.ANSI
    IO.puts(blue() <> "#{label} :" <> yellow() <> " #{inspect value}")
    value
  end
end
