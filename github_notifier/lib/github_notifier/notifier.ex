defmodule GithubNotifier.Notifier do
  alias GithubNotifier.Extractor
  alias GithubNotifier.Models
  alias GithubNotifier.TaskSupervisor
  alias GithubNotifier.Utils.SkipPolicy

  defmodule FetchError do
    defexception [:message]
  end

  def notify(request_id, pipeline_id, block_id \\ nil) do
    pipeline = fetch(:pipeline, fn -> Models.Pipeline.find(pipeline_id) end)
    project = fetch(:project, fn -> Models.Project.find(pipeline.project_id) end)

    if reports?(project, pipeline, block_id) do
      repo_proxy = fetch(:repo_proxy, fn -> Models.RepoProxy.find(pipeline.hook_id) end)

      pipeline
      |> Extractor.extract(block_id, repo_proxy, project)
      |> with_suppression(pipeline)
      |> GithubNotifier.Status.create(request_id)
    end
  end

  def notify_with_summary(request_id, pipeline_id) do
    pipeline = fetch(:pipeline, fn -> Models.Pipeline.find(pipeline_id) end)
    repo_proxy = fetch(:repo_proxy, fn -> Models.RepoProxy.find(pipeline.hook_id) end)
    project = fetch(:project, fn -> Models.Project.find(pipeline.project_id) end)

    pipeline_summary =
      fetch(:pipeline_summary, fn -> Models.PipelineSummary.find(pipeline_id) end)

    case project do
      nil ->
        nil

      project ->
        pipeline
        |> Extractor.extract_with_summary(repo_proxy, project, pipeline_summary)
        |> with_suppression(pipeline)
        |> GithubNotifier.Status.create(request_id)
    end
  end

  defp reports?(nil, _pipeline, _block_id), do: false

  defp reports?(project, pipeline, block_id),
    do: Extractor.levels(project, pipeline, block_id) != []

  # The suppression decision rides along on the request: repository_hub
  # resolves it against the last delivered state for the check, so a decision
  # that flipped mid-pipeline cannot strand a pending status.
  defp with_suppression(nil, _pipeline), do: nil

  defp with_suppression(data, pipeline) do
    put_suppress(data, SkipPolicy.suppress?(pipeline, fetch_task(pipeline)))
  end

  defp put_suppress(data, suppress) when is_list(data),
    do: Enum.map(data, &put_suppress(&1, suppress))

  defp put_suppress(nil, _suppress), do: nil
  defp put_suppress(data, suppress), do: Map.put(data, :suppress, suppress)

  defp fetch_task(%{triggered_by: triggered_by, scheduler_task_id: task_id})
       when triggered_by in [:SCHEDULE, :MANUAL_RUN] and task_id not in [nil, ""] do
    task =
      Task.Supervisor.async_nolink(TaskSupervisor, fn -> Models.Periodic.find(task_id) end)

    case Task.yield(task, Models.Periodic.lookup_budget()) ||
           Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      _ ->
        Watchman.increment("fetch_periodic.timeout")
        nil
    end
  end

  defp fetch_task(_pipeline), do: nil

  # A fetch that outlives its budget is killed, so it stops holding its gRPC
  # call while the message waits to be redelivered.
  defp fetch(name, fun) do
    task = Task.Supervisor.async_nolink(TaskSupervisor, fun)

    case Task.yield(task, fetch_timeout()) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      {:exit, _reason} ->
        raise FetchError, "#{name} fetch failed"

      nil ->
        Watchman.increment("fetch_#{name}.timeout")
        raise FetchError, "#{name} fetch timed out after #{fetch_timeout()}ms"
    end
  end

  defp fetch_timeout, do: Application.get_env(:github_notifier, :fetch_timeout, 5_000)
end
