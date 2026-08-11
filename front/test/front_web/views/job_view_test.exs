defmodule FrontWeb.JobViewTest do
  use ExUnit.Case, async: true

  alias FrontWeb.JobView

  describe "job_timer/1" do
    test "shows placeholder for stopped jobs that never started" do
      job = %{
        state: "stopped",
        timeline: %{
          started_at: nil,
          finished_at: 1_715_000_000
        }
      }

      assert JobView.job_timer(job) == "<span class='f5 code'>--:--</span>"
    end
  end

  describe "logs helpers" do
    test "marks fast-failed job stopped before execution as having no logs" do
      job = %{
        state: "stopped",
        failure_reason: "",
        timeline: %{
          started_at: nil,
          finished_at: 1_715_000_000
        }
      }

      refute JobView.logs_available?(job)

      assert JobView.missing_logs_message(job) ==
               "This job was stopped before it started, so no logs were produced."
    end

    test "keeps logs available for stopped jobs that actually started" do
      job = %{
        state: "stopped",
        failure_reason: "",
        timeline: %{
          started_at: 1_714_999_900,
          finished_at: 1_715_000_000
        }
      }

      assert JobView.logs_available?(job)
      assert JobView.missing_logs_message(job) == nil
    end
  end
end
