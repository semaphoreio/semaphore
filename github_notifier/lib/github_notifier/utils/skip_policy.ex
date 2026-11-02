defmodule GithubNotifier.Utils.SkipPolicy do
  @moduledoc """
  Decides whether a commit status should be suppressed.

  A run canceled by the pipeline strategy never reached a verdict, so
  reporting it would replace a result with one that stands for nothing. Only
  in an implicit queue, though: that queue holds one ref and one pipeline
  file, so the run that cancelled it reports the same check and the check
  still gets an answer. A named queue is shared across refs and projects, and
  dropping the status there would leave a ref with no answer at all.

  Otherwise the notification skip flags of the scheduler task behind the
  workflow decide. A flag applies to every pipeline started by that task with
  that trigger, reruns included: "don't send" means don't send. A task that
  can't be resolved never suppresses.

  The answer is a request flag, not a local drop: repository_hub resolves it
  under the row lock that already serializes delivery for the check, so a
  suppressed terminal state is still delivered when a PENDING is outstanding.
  """

  @interrupted [:CANCELED, :STOPPED]

  def suppress?(pipeline, task \\ nil)

  # Decided before the task, which a hook-triggered run never has: the
  # strategy cancels runs whatever started them.
  def suppress?(
        %{state: :DONE, result: result, result_reason: :STRATEGY, queue_type: :IMPLICIT},
        _task
      )
      when result in @interrupted,
      do: true

  def suppress?(_pipeline, nil), do: false

  def suppress?(pipeline, task) do
    case pipeline.triggered_by do
      :SCHEDULE -> task.skip_scheduled_run_notifications == true
      :MANUAL_RUN -> task.skip_manual_run_notifications == true
      _ -> false
    end
  end
end
