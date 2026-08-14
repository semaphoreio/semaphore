defmodule GithubNotifier.Utils.SkipPolicy do
  @moduledoc """
  Decides whether a commit status should be skipped based on what triggered
  the pipeline's workflow, the task's commit status policy and the project's
  commit status settings.

  A task policy of ALWAYS or NEVER wins; FOLLOW_PROJECT (or an unresolvable
  task) falls back to the project settings: scheduled pipelines don't post
  when the project sets `skip_scheduled_run`, manually run scheduler tasks
  don't post when the project sets `skip_manual_run`. Reruns always post,
  since they inherit the trigger of the original workflow.
  """

  def skip?(project, pipeline, task \\ nil) do
    cond do
      rerun?(pipeline) -> false
      pipeline.triggered_by == :SCHEDULE -> resolve(task, project, "skip_scheduled_run")
      pipeline.triggered_by == :MANUAL_RUN -> resolve(task, project, "skip_manual_run")
      true -> false
    end
  end

  defp rerun?(pipeline) do
    pipeline.workflow_rerun_of not in [nil, ""] or pipeline.ppl_triggered_by == :PARTIAL_RE_RUN
  end

  defp resolve(%{commit_status: :ALWAYS}, _project, _key), do: false
  defp resolve(%{commit_status: :NEVER}, _project, _key), do: true
  defp resolve(_task, project, key), do: setting?(project, key)

  defp setting?(%{status: nil}, _key), do: false
  defp setting?(%{status: status}, key), do: Map.get(status, key, false) == true
end
