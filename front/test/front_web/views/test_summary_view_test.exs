defmodule FrontWeb.TestSummaryViewTest do
  use FrontWeb.ConnCase
  doctest FrontWeb.TestSummaryView, import: true

  alias Front.Models.TestSummary
  alias FrontWeb.TestSummaryView

  describe "visible?" do
    test "should return correct visibility state for test summaries" do
      assert TestSummaryView.visible?(nil) == false
      assert TestSummaryView.visible?(%TestSummary{}) == false
      assert TestSummaryView.visible?(%TestSummary{total: 0}) == false
      assert TestSummaryView.visible?(%TestSummary{total: -1}) == false
      assert TestSummaryView.visible?(%TestSummary{passed: 1}) == false
      assert TestSummaryView.visible?(%TestSummary{failed: 1}) == false
      assert TestSummaryView.visible?(%TestSummary{total: 0, passed: 1}) == false
      assert TestSummaryView.visible?(%TestSummary{total: 1}) == false
      assert TestSummaryView.visible?(%TestSummary{total: 1, passed: 1}, :FAILED) == false
      assert TestSummaryView.visible?(%TestSummary{total: 1, passed: 1}, :PASSED) == true
      assert TestSummaryView.visible?(%TestSummary{total: 1, failed: 1}, :PASSED) == false
      assert TestSummaryView.visible?(%TestSummary{total: 1, failed: 1}, :FAILED) == true
      assert TestSummaryView.visible?(%TestSummary{total: 1, failed: 1}, :CANCELED) == true
      assert TestSummaryView.visible?(%TestSummary{total: 1, passed: 1}, :CANCELED) == true
    end
  end

  describe "state_class" do
    test "should return proper class based on summary state" do
      assert TestSummaryView.state_class(%TestSummary{}) == ""
      assert TestSummaryView.state_class(%TestSummary{total: 1}) == ""
      assert TestSummaryView.state_class(%TestSummary{total: 1, passed: 1}) == "green"
      assert TestSummaryView.state_class(%TestSummary{total: 1, failed: 1}) == "red"
      assert TestSummaryView.state_class(%TestSummary{total: 1, failed: 1, passed: 1}) == "red"
    end

    test "should return no class when pipeline and summary state mismatches" do
      assert TestSummaryView.state_class(%TestSummary{total: 1, passed: 1}, :PASSED) == "green"
      assert TestSummaryView.state_class(%TestSummary{total: 1, passed: 1}, :FAILED) == "gray"
      assert TestSummaryView.state_class(%TestSummary{total: 1, passed: 1}, :CANCELED) == "gray"
      assert TestSummaryView.state_class(%TestSummary{total: 1, passed: 1}, :STOPPED) == "gray"

      assert TestSummaryView.state_class(%TestSummary{total: 1, failed: 1}, :FAILED) == "red"
      assert TestSummaryView.state_class(%TestSummary{total: 1, failed: 1}, :PASSED) == "gray"
      assert TestSummaryView.state_class(%TestSummary{total: 1, failed: 1}, :CANCELED) == "gray"
      assert TestSummaryView.state_class(%TestSummary{total: 1, failed: 1}, :STOPPED) == "gray"
    end
  end

  describe "summary_content" do
    test "should return proper text when summary is in passing state" do
      assert TestSummaryView.summary_content(%TestSummary{total: 1, passed: 1}, :PASSED) ==
               "1 test passed"

      assert TestSummaryView.summary_content(%TestSummary{total: 1, passed: 100}, :PASSED) ==
               "100 tests passed"

      assert TestSummaryView.summary_content(%TestSummary{total: 1, passed: 100}, :PASSED) ==
               "100 tests passed"

      assert TestSummaryView.summary_content(%TestSummary{total: 1, passed: 0}, :PASSED) ==
               ""
    end

    test "should return proper text when summary is in failing state" do
      assert TestSummaryView.summary_content(%TestSummary{total: 1, failed: 1}, :FAILED) ==
               "1 test failed"

      assert TestSummaryView.summary_content(%TestSummary{total: 1, failed: 100}, :FAILED) ==
               "100 tests failed"

      assert TestSummaryView.summary_content(
               %TestSummary{total: 100, failed: 1, passed: 10},
               :FAILED
             ) ==
               "1 test failed"

      assert TestSummaryView.summary_content(
               %TestSummary{total: 100, failed: 0, passed: 10},
               :FAILED
             ) ==
               ""
    end

    test "should return no text in other cases" do
      assert TestSummaryView.summary_content(%TestSummary{}) == ""
      assert TestSummaryView.summary_content(%TestSummary{passed: 1}) == ""
      assert TestSummaryView.summary_content(%TestSummary{total: 1}) == ""
    end
  end
end
