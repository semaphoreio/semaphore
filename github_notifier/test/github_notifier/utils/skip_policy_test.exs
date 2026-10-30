defmodule GithubNotifier.Utils.SkipPolicyTest do
  use ExUnit.Case, async: true

  alias GithubNotifier.Models.Periodic
  alias GithubNotifier.Utils.SkipPolicy

  describe "suppress?/2 for a run canceled by the strategy" do
    test "suppresses it whatever started the workflow" do
      for trigger <- [:HOOK, :API, :SCHEDULE, :MANUAL_RUN],
          result <- [:CANCELED, :STOPPED] do
        assert SkipPolicy.suppress?(canceled(trigger, result, :STRATEGY)),
               "#{trigger}/#{result} canceled by the strategy must not report"
      end
    end

    # The decision cannot depend on the task: a hook-triggered run has none,
    # and the strategy cancels those too.
    test "suppresses it with no task to resolve" do
      assert SkipPolicy.suppress?(canceled(:HOOK, :CANCELED, :STRATEGY), nil)
    end

    test "does not suppress a run canceled for any other reason" do
      for reason <- [:USER, :TIMEOUT, :FAST_FAILING, :INTERNAL, :DELETED, :STUCK] do
        refute SkipPolicy.suppress?(canceled(:HOOK, :CANCELED, reason)),
               "a run canceled by #{reason} still owes the check a result"
      end
    end

    test "does not suppress a run that reached a verdict" do
      refute SkipPolicy.suppress?(canceled(:HOOK, :PASSED, :STRATEGY))
      refute SkipPolicy.suppress?(canceled(:HOOK, :FAILED, :STRATEGY))
    end

    # A named queue is shared across refs and projects, so the run that
    # cancelled this one reports somewhere else and this ref would be left
    # with no answer at all. Reporting the cancellation is the lesser evil.
    test "does not suppress outside an implicit queue" do
      for queue_type <- [:USER_GENERATED, nil] do
        refute SkipPolicy.suppress?(canceled(:HOOK, :CANCELED, :STRATEGY, queue_type)),
               "queue_type #{inspect(queue_type)} must still report"
      end
    end
  end

  describe "suppress?/2" do
    test "suppresses scheduled pipelines when the task skips scheduled run notifications" do
      assert SkipPolicy.suppress?(pipeline(:SCHEDULE), task(scheduled: true))
    end

    test "suppresses manual runs when the task skips manual run notifications" do
      assert SkipPolicy.suppress?(pipeline(:MANUAL_RUN), task(manual: true))
    end

    # Reruns are covered by the trigger alone: suppress?/2 reads only
    # triggered_by, and a rerun keeps the trigger of the original workflow
    # because plumber copies request_args wholesale when it reschedules
    # (plumber/ppl/lib/ppl/workflow/workflow_api_server.ex extract_schedule_params/2,
    # which overrides only request_token, requester_id, wf_id, wf_rebuild_of
    # and label). There is nothing rerun-specific to assert here - a test that
    # set workflow_rerun_of or ppl_triggered_by would pass against any
    # implementation, including one with no rerun awareness at all.

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
    %{triggered_by: triggered_by, scheduler_task_id: "task-1"}
  end

  defp canceled(triggered_by, result, result_reason, queue_type \\ :IMPLICIT) do
    triggered_by
    |> pipeline()
    |> Map.merge(%{
      state: :DONE,
      result: result,
      result_reason: result_reason,
      queue_type: queue_type
    })
  end

  defp task(opts) do
    %Periodic{
      id: "task-1",
      skip_scheduled_run_notifications: Keyword.get(opts, :scheduled, false),
      skip_manual_run_notifications: Keyword.get(opts, :manual, false)
    }
  end
end
