defmodule GithubNotifier.Utils.SkipPolicy do
  @moduledoc """
  Decides whether a commit status should be skipped, based on what triggered
  the pipeline's workflow and the notification skip flags of the scheduler
  task behind it.

  A flag applies to every pipeline started by that task with that trigger,
  reruns included: "don't send" means don't send. Pipelines started by a hook
  or the API are never skipped, and a task that can't be resolved never skips.
  """

  def skip?(pipeline, task \\ nil)

  def skip?(_pipeline, nil), do: false

  def skip?(pipeline, task) do
    case pipeline.triggered_by do
      :SCHEDULE -> task.skip_scheduled_run_notifications == true
      :MANUAL_RUN -> task.skip_manual_run_notifications == true
      _ -> false
    end
  end
end
