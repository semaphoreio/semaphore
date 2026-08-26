defmodule GithubNotifier.Utils.SkipPolicy do
  @moduledoc """
  Decides whether a commit status should be suppressed, based on what
  triggered the pipeline's workflow and the notification skip flags of the
  scheduler task behind it.

  A flag applies to every pipeline started by that task with that trigger,
  reruns included: "don't send" means don't send. Pipelines started by a hook
  or the API are never suppressed, and a task that can't be resolved never
  suppresses.

  The answer is a request flag, not a local drop: repository_hub resolves it
  under the row lock that already serializes delivery for the check, so a
  suppressed terminal state is still delivered when a PENDING is outstanding.
  """

  def suppress?(pipeline, task \\ nil)

  def suppress?(_pipeline, nil), do: false

  def suppress?(pipeline, task) do
    case pipeline.triggered_by do
      :SCHEDULE -> task.skip_scheduled_run_notifications == true
      :MANUAL_RUN -> task.skip_manual_run_notifications == true
      _ -> false
    end
  end
end
