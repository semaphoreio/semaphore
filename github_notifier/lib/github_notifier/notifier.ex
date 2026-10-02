defmodule GithubNotifier.Notifier do
  require Logger

  alias GithubNotifier.TaskSupervisor
  alias GithubNotifier.Models

  # Most Models.*.find/1 calls issue gRPC requests with a 30s deadline (see
  # models/repo_proxy.ex, models/pipeline.ex); bound each surrounding task to
  # the same budget (this also caps the otherwise-unbounded PipelineSummary
  # lookup).
  #
  # Previously each fetch was `async_nolink(...) |> Task.yield()`, and
  # `Task.yield/1` defaults to a 5s timeout. When a `describe` was merely slow
  # (5-30s, e.g. while a dependency's DB pool is saturated during a burst),
  # `Task.yield` returned `nil` while the call was still in flight, and the
  # strict `{:ok, x} = fetch_*(...)` match then raised `{:badmatch, nil}`.
  # That crash skipped `Status.create`, so the commit status was never posted
  # and the PR's required check hung until a human re-pushed.
  @default_fetch_timeout 30_000

  def notify(request_id, pipeline_id, block_id \\ nil) do
    with {:ok, pipeline} <- fetch_pipeline(pipeline_id),
         {:ok, repo_proxy} <- fetch_repo_proxy(pipeline.hook_id),
         {:ok, project} <- fetch_project(pipeline.project_id) do
      case project do
        nil ->
          nil

        project ->
          data = GithubNotifier.Extractor.extract(pipeline, block_id, repo_proxy, project)
          GithubNotifier.Status.create(data, request_id)
      end
    else
      {:error, stage} -> retry!(stage, pipeline_id)
    end
  end

  def notify_with_summary(request_id, pipeline_id) do
    with {:ok, pipeline} <- fetch_pipeline(pipeline_id),
         {:ok, repo_proxy} <- fetch_repo_proxy(pipeline.hook_id),
         {:ok, project} <- fetch_project(pipeline.project_id),
         {:ok, pipeline_summary} <- fetch_pipeline_summary(pipeline_id) do
      case project do
        nil ->
          nil

        project ->
          data =
            GithubNotifier.Extractor.extract_with_summary(
              pipeline,
              repo_proxy,
              project,
              pipeline_summary
            )

          GithubNotifier.Status.create(data, request_id)
      end
    else
      {:error, stage} -> retry!(stage, pipeline_id)
    end
  end

  # Raise so the Tackle consumer redelivers the message (retry_delay /
  # retry_limit) instead of dropping the status. A transient backend slowdown
  # then simply retries once the dependency recovers; only a sustained outage
  # exhausts the retry budget and dead-letters.
  defp retry!(stage, pipeline_id) do
    raise "github_notifier: #{stage} fetch unavailable for pipeline #{pipeline_id}; will retry"
  end

  defp fetch_pipeline_summary(pipeline_id),
    do: fetch(:pipeline_summary, fn -> Models.PipelineSummary.find(pipeline_id) end)

  defp fetch_repo_proxy(hook_id), do: fetch(:repo_proxy, fn -> Models.RepoProxy.find(hook_id) end)

  defp fetch_project(project_id), do: fetch(:project, fn -> Models.Project.find(project_id) end)

  defp fetch_pipeline(pipeline_id),
    do: fetch(:pipeline, fn -> Models.Pipeline.find(pipeline_id) end)

  # Runs `fun` in a supervised task bounded by the fetch timeout.
  #
  # Returns `{:ok, result}` when the call completes (`result` may be `nil` when
  # the record is genuinely absent — callers already handle that), or
  # `{:error, stage}` when the call times out or the task crashes, so the
  # caller can retry rather than crash with `{:badmatch, nil}`.
  defp fetch(stage, fun) do
    task = Task.Supervisor.async_nolink(TaskSupervisor, fun)

    case Task.yield(task, fetch_timeout()) || Task.shutdown(task) do
      {:ok, result} ->
        {:ok, result}

      other ->
        Logger.error("Fetch #{stage} failed or timed out: #{inspect(other)}")
        {:error, stage}
    end
  end

  defp fetch_timeout do
    Application.get_env(:github_notifier, :fetch_timeout, @default_fetch_timeout)
  end
end
