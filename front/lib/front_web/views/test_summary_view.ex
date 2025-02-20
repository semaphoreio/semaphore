defmodule FrontWeb.TestSummaryView do
  use FrontWeb, :view

  alias Front.Models.TestSummary
  import TestSummary, only: [is_passed?: 1, is_failed?: 1, is_empty?: 1]
  import FrontWeb.SharedHelpers, only: [pluralize: 2]

  @spec visible?(TestSummary.t() | nil, atom()) :: boolean()
  def visible?(_, state \\ nil)

  def visible?(test_summary = %TestSummary{}, state) when not is_empty?(test_summary) do
    summary_content(test_summary, state) |> String.trim() != ""
  end

  def visible?(_, _), do: false

  @spec state_class(TestSummary.t(), atom()) :: String.t()
  def state_class(_, state \\ nil)

  def state_class(test_summary = %TestSummary{}, :FAILED) when is_passed?(test_summary),
    do: "gray"

  def state_class(test_summary = %TestSummary{}, :PASSED) when is_failed?(test_summary),
    do: "gray"

  def state_class(_test_summary = %TestSummary{}, :STOPPED),
    do: "gray"

  def state_class(_test_summary = %TestSummary{}, :CANCELED),
    do: "gray"

  def state_class(test_summary = %TestSummary{}, _) when is_passed?(test_summary), do: "green"
  def state_class(test_summary = %TestSummary{}, _) when is_failed?(test_summary), do: "red"
  def state_class(_, _), do: ""

  @spec summary_content(TestSummary.t(), atom()) :: String.t()
  def summary_content(_, state \\ nil)

  def summary_content(test_summary = %TestSummary{}, :PASSED) when is_passed?(test_summary) do
    count = TestSummary.passed(test_summary)
    "#{pluralize("test", count)} passed"
  end

  def summary_content(_test_summary = %TestSummary{}, :PASSED), do: ""

  def summary_content(test_summary = %TestSummary{}, :FAILED) when is_failed?(test_summary) do
    count = TestSummary.failed(test_summary)
    "#{pluralize("test", count)} failed"
  end

  def summary_content(_test_summary = %TestSummary{}, :FAILED), do: ""

  def summary_content(test_summary = %TestSummary{}, _) when is_passed?(test_summary) do
    count = TestSummary.passed(test_summary)
    "#{pluralize("test", count)} passed"
  end

  def summary_content(test_summary = %TestSummary{}, _) when is_failed?(test_summary) do
    count = TestSummary.failed(test_summary)
    "#{pluralize("test", count)} failed"
  end

  def summary_content(_, _), do: ""
end
