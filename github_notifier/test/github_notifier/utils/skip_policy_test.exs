defmodule GithubNotifier.Utils.SkipPolicyTest do
  use ExUnit.Case, async: true

  alias GithubNotifier.Models.Periodic
  alias GithubNotifier.Utils.SkipPolicy

  describe "suppress?/2" do
    test "suppresses scheduled pipelines when the task skips scheduled run notifications" do
      assert SkipPolicy.suppress?(pipeline(:SCHEDULE), task(scheduled: true))
    end

    test "suppresses manual runs when the task skips manual run notifications" do
      assert SkipPolicy.suppress?(pipeline(:MANUAL_RUN), task(manual: true))
    end

    test "a set flag also suppresses reruns of that trigger" do
      pipeline = %{pipeline(:SCHEDULE) | workflow_rerun_of: "wf-1"}

      assert SkipPolicy.suppress?(pipeline, task(scheduled: true))
    end

    test "a set flag also suppresses partial re-runs of that trigger" do
      pipeline = %{pipeline(:SCHEDULE) | ppl_triggered_by: :PARTIAL_RE_RUN}

      assert SkipPolicy.suppress?(pipeline, task(scheduled: true))
    end

    test "does not suppress when the flag for that trigger is unset" do
      refute SkipPolicy.suppress?(pipeline(:SCHEDULE), task(manual: true))
      refute SkipPolicy.suppress?(pipeline(:MANUAL_RUN), task(scheduled: true))
    end

    test "never suppresses hook or api pipelines" do
      both = task(scheduled: true, manual: true)

      refute SkipPolicy.suppress?(pipeline(:HOOK), both)
      refute SkipPolicy.suppress?(pipeline(:API), both)
    end

    test "never suppresses when the task can't be resolved" do
      refute SkipPolicy.suppress?(pipeline(:SCHEDULE), nil)
      refute SkipPolicy.suppress?(pipeline(:MANUAL_RUN))
    end
  end

  defp pipeline(triggered_by) do
    %{
      triggered_by: triggered_by,
      ppl_triggered_by: :WORKFLOW,
      workflow_rerun_of: "",
      scheduler_task_id: "task-1"
    }
  end

  defp task(opts) do
    %Periodic{
      id: "task-1",
      skip_scheduled_run_notifications: Keyword.get(opts, :scheduled, false),
      skip_manual_run_notifications: Keyword.get(opts, :manual, false)
    }
  end
end
