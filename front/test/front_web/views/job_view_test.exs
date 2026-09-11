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

  # Built as %Front.Models.Job{} rather than a bare map: job_moment/1 ends in a
  # catch-all returning nil, so a hand-rolled shape would keep passing after a rename
  # of the model's timeline while the header silently lost its timestamp.
  describe "job_moment/1" do
    test "anchors on the job's own start, not the workflow it came from" do
      job = %Front.Models.Job{
        timeline: %{
          created_at: 1_788_948_084,
          started_at: 1_788_948_090,
          finished_at: 1_788_948_109
        }
      }

      assert JobView.job_moment(job) == {"started", "2026-09-09T10:01:30Z"}
    end

    test "falls back to creation for a job that never started" do
      job = %Front.Models.Job{
        timeline: %{
          created_at: 1_788_948_084,
          started_at: nil,
          finished_at: nil
        }
      }

      assert JobView.job_moment(job) == {"created", "2026-09-09T10:01:24Z"}
    end

    test "returns nothing when the job has no timestamps at all" do
      job = %Front.Models.Job{timeline: %{created_at: nil, started_at: nil, finished_at: nil}}

      assert JobView.job_moment(job) == nil
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
