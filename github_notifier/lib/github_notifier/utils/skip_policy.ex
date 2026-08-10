defmodule GithubNotifier.Utils.SkipPolicy do
  @moduledoc """
  Decides whether a commit status should be skipped based on what triggered
  the pipeline's workflow and the project's commit status settings.

  Scheduled pipelines don't post commit statuses when the project sets
  `skip_scheduled_run`; manually run scheduler tasks don't post when the
  project sets `skip_manual_run`. Reruns always post, since they inherit
  the trigger of the original workflow.
  """

  def skip?(project, pipeline) do
    cond do
      rerun?(pipeline) -> false
      pipeline.triggered_by == :SCHEDULE -> setting?(project, "skip_scheduled_run")
      pipeline.triggered_by == :MANUAL_RUN -> setting?(project, "skip_manual_run")
      true -> false
    end
  end

  defp rerun?(pipeline) do
    pipeline.workflow_rerun_of not in [nil, ""] or pipeline.ppl_triggered_by == :PARTIAL_RE_RUN
  end

  defp setting?(%{status: nil}, _key), do: false
  defp setting?(%{status: status}, key), do: Map.get(status, key, false) == true
end
