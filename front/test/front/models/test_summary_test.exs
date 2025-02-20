defmodule Front.Models.TestSummaryTest do
  use ExUnit.Case
  doctest Front.Models.TestSummary
  alias Front.Models.TestSummary

  setup do
    [
      empty: %TestSummary{},
      passed: %TestSummary{total: 1, passed: 1},
      failed: %TestSummary{total: 1, failed: 1},
      error: %TestSummary{total: 1, error: 1},
      failed_and_error: %TestSummary{total: 2, error: 1, failed: 1},
      skipped: %TestSummary{total: 1, skipped: 1},
      disabled: %TestSummary{total: 1, disabled: 1},
      skipped_and_disabled: %TestSummary{total: 2, skipped: 1, disabled: 1}
    ]
  end

  describe "initialization" do
    test "should have proper zero state", summary do
      assert summary.empty == %TestSummary{
               total: 0,
               passed: 0,
               skipped: 0,
               error: 0,
               failed: 0,
               disabled: 0,
               duration: 0
             }
    end
  end

  describe "guards" do
    test "is_failed?", summary do
      assert TestSummary.is_failed?(summary.empty) == false
      assert TestSummary.is_failed?(summary.passed) == false
      assert TestSummary.is_failed?(summary.failed) == true
      assert TestSummary.is_failed?(summary.error) == true
      assert TestSummary.is_failed?(summary.failed_and_error) == true
      assert TestSummary.is_failed?(summary.skipped) == false
      assert TestSummary.is_failed?(summary.disabled) == false
      assert TestSummary.is_failed?(summary.skipped_and_disabled) == false
    end

    test "is_passed?", summary do
      assert TestSummary.is_passed?(summary.empty) == false
      assert TestSummary.is_passed?(summary.passed) == true
      assert TestSummary.is_passed?(summary.failed) == false
      assert TestSummary.is_passed?(summary.error) == false
      assert TestSummary.is_passed?(summary.failed_and_error) == false
      assert TestSummary.is_passed?(summary.skipped) == true
      assert TestSummary.is_passed?(summary.disabled) == true
      assert TestSummary.is_passed?(summary.skipped_and_disabled) == true
    end

    test "is_empty?", summary do
      assert TestSummary.is_empty?(summary.empty) == true
      assert TestSummary.is_empty?(summary.passed) == false
      assert TestSummary.is_empty?(summary.failed) == false
      assert TestSummary.is_empty?(summary.error) == false
      assert TestSummary.is_empty?(summary.failed_and_error) == false
      assert TestSummary.is_empty?(summary.skipped) == false
      assert TestSummary.is_empty?(summary.disabled) == false
      assert TestSummary.is_empty?(summary.skipped_and_disabled) == false
    end
  end

  describe "counters" do
    test "total", summary do
      assert TestSummary.total(summary.empty) == 0
      assert TestSummary.total(summary.passed) == 1
      assert TestSummary.total(summary.failed) == 1
      assert TestSummary.total(summary.error) == 1
      assert TestSummary.total(summary.failed_and_error) == 2
      assert TestSummary.total(summary.skipped) == 1
      assert TestSummary.total(summary.disabled) == 1
      assert TestSummary.total(summary.skipped_and_disabled) == 2
    end

    test "passed", summary do
      assert TestSummary.passed(summary.empty) == 0
      assert TestSummary.passed(summary.passed) == 1
      assert TestSummary.passed(summary.failed) == 0
      assert TestSummary.passed(summary.error) == 0
      assert TestSummary.passed(summary.failed_and_error) == 0
      assert TestSummary.passed(summary.skipped) == 0
      assert TestSummary.passed(summary.disabled) == 0
      assert TestSummary.passed(summary.skipped_and_disabled) == 0
    end

    test "failed", summary do
      assert TestSummary.failed(summary.empty) == 0
      assert TestSummary.failed(summary.passed) == 0
      assert TestSummary.failed(summary.failed) == 1
      assert TestSummary.failed(summary.error) == 1
      assert TestSummary.failed(summary.failed_and_error) == 2
      assert TestSummary.failed(summary.skipped) == 0
      assert TestSummary.failed(summary.disabled) == 0
      assert TestSummary.failed(summary.skipped_and_disabled) == 0
    end

    test "skipped", summary do
      assert TestSummary.skipped(summary.empty) == 0
      assert TestSummary.skipped(summary.passed) == 0
      assert TestSummary.skipped(summary.failed) == 0
      assert TestSummary.skipped(summary.error) == 0
      assert TestSummary.skipped(summary.failed_and_error) == 0
      assert TestSummary.skipped(summary.skipped) == 1
      assert TestSummary.skipped(summary.disabled) == 1
      assert TestSummary.skipped(summary.skipped_and_disabled) == 2
    end
  end

  describe "JobSummary loader" do
    alias InternalApi.Velocity.{
      JobSummary,
      Summary
    }

    setup do
      gen_job_summary = fn summary ->
        JobSummary.new(
          job_id: Ecto.UUID.generate(),
          pipeline_id: Ecto.UUID.generate(),
          summary: summary
        )
      end

      [
        empty: JobSummary.new(),
        correct:
          gen_job_summary.(
            Summary.new(
              total: 15,
              passed: 1,
              skipped: 3,
              error: 4,
              failed: 2,
              disabled: 5,
              duration: 6
            )
          ),
        with_missing_fields: gen_job_summary.(Summary.new(total: 2))
      ]
    end

    test "loads from job summary", job_summary do
      assert TestSummary.load(job_summary.correct) == %TestSummary{
               total: 15,
               passed: 1,
               skipped: 3,
               error: 4,
               failed: 2,
               disabled: 5,
               duration: 6
             }

      assert TestSummary.load(job_summary.with_missing_fields) == %TestSummary{
               total: 2,
               passed: 0,
               skipped: 0,
               error: 0,
               failed: 0,
               disabled: 0,
               duration: 0
             }

      assert TestSummary.load(job_summary.empty) == %TestSummary{
               total: 0,
               passed: 0,
               skipped: 0,
               error: 0,
               failed: 0,
               disabled: 0,
               duration: 0
             }
    end
  end

  describe "PipelineSummary loader" do
    alias InternalApi.Velocity.{
      PipelineSummary,
      Summary
    }

    setup do
      gen_pipeline_summary = fn summary ->
        PipelineSummary.new(
          pipeline_id: Ecto.UUID.generate(),
          summary: summary
        )
      end

      [
        empty: PipelineSummary.new(),
        correct:
          gen_pipeline_summary.(
            Summary.new(
              total: 15,
              passed: 1,
              skipped: 3,
              error: 4,
              failed: 2,
              disabled: 5,
              duration: 6
            )
          ),
        with_missing_fields: gen_pipeline_summary.(Summary.new(total: 2))
      ]
    end

    test "loads from pipeline summary", pipeline_summary do
      assert TestSummary.load(pipeline_summary.correct) == %TestSummary{
               total: 15,
               passed: 1,
               skipped: 3,
               error: 4,
               failed: 2,
               disabled: 5,
               duration: 6
             }

      assert TestSummary.load(pipeline_summary.with_missing_fields) == %TestSummary{
               total: 2,
               passed: 0,
               skipped: 0,
               error: 0,
               failed: 0,
               disabled: 0,
               duration: 0
             }

      assert TestSummary.load(pipeline_summary.empty) == %TestSummary{
               total: 0,
               passed: 0,
               skipped: 0,
               error: 0,
               failed: 0,
               disabled: 0,
               duration: 0
             }
    end
  end

  describe "common loader" do
    test "works as an identity on self" do
      assert TestSummary.load(%TestSummary{}) == %TestSummary{
               total: 0,
               passed: 0,
               skipped: 0,
               error: 0,
               failed: 0,
               disabled: 0,
               duration: 0
             }

      assert TestSummary.load(%TestSummary{
               total: 15,
               passed: 1,
               skipped: 3,
               error: 4,
               failed: 2,
               disabled: 5,
               duration: 6
             }) == %TestSummary{
               total: 15,
               passed: 1,
               skipped: 3,
               error: 4,
               failed: 2,
               disabled: 5,
               duration: 6
             }
    end

    test "works as an identity on nil" do
      assert TestSummary.load(nil) == nil
    end
  end
end
