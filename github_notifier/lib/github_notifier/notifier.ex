defmodule GithubNotifier.Notifier do
  alias GithubNotifier.TaskSupervisor
  alias GithubNotifier.Models
  alias GithubNotifier.Utils.SkipPolicy

  def notify(request_id, pipeline_id, block_id \\ nil) do
    {:ok, pipeline} = fetch_pipeline(pipeline_id)
    {:ok, repo_proxy} = fetch_repo_proxy(pipeline.hook_id)
    {:ok, project} = fetch_project(pipeline.project_id)

    case project do
      nil ->
        nil

      project ->
        if skip?(pipeline) do
          Watchman.increment("set_commit_status.skipped")
        else
          data = GithubNotifier.Extractor.extract(pipeline, block_id, repo_proxy, project)
          GithubNotifier.Status.create(data, request_id)
        end
    end
  end

  def notify_with_summary(request_id, pipeline_id) do
    {:ok, pipeline} = fetch_pipeline(pipeline_id)
    {:ok, repo_proxy} = fetch_repo_proxy(pipeline.hook_id)
    {:ok, project} = fetch_project(pipeline.project_id)
    {:ok, pipeline_summary} = fetch_pipeline_summary(pipeline_id)

    case project do
      nil ->
        nil

      project ->
        if skip?(pipeline) do
          Watchman.increment("set_commit_status.skipped")
        else
          data =
            GithubNotifier.Extractor.extract_with_summary(
              pipeline,
              repo_proxy,
              project,
              pipeline_summary
            )

          GithubNotifier.Status.create(data, request_id)
        end
    end
  end

  defp skip?(pipeline), do: SkipPolicy.skip?(pipeline, fetch_task(pipeline))

  defp fetch_task(%{triggered_by: triggered_by, scheduler_task_id: task_id})
       when triggered_by in [:SCHEDULE, :MANUAL_RUN] and task_id not in [nil, ""] do
    task =
      Task.Supervisor.async_nolink(TaskSupervisor, fn -> Models.Periodic.find(task_id) end)

    case Task.yield(task, 2_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      _ ->
        Watchman.increment("fetch_periodic.timeout")
        nil
    end
  end

  defp fetch_task(_pipeline), do: nil

  defp fetch_pipeline_summary(pipeline_id) do
    Task.Supervisor.async_nolink(
      TaskSupervisor,
      fn ->
        Models.PipelineSummary.find(pipeline_id)
      end
    )
    |> Task.yield()
  end

  defp fetch_repo_proxy(hook_id) do
    Task.Supervisor.async_nolink(
      TaskSupervisor,
      fn ->
        Models.RepoProxy.find(hook_id)
      end
    )
    |> Task.yield()
  end

  defp fetch_project(project_id) do
    Task.Supervisor.async_nolink(
      TaskSupervisor,
      fn ->
        Models.Project.find(project_id)
      end
    )
    |> Task.yield()
  end

  defp fetch_pipeline(pipeline_id) do
    Task.Supervisor.async_nolink(
      TaskSupervisor,
      fn ->
        Models.Pipeline.find(pipeline_id)
      end
    )
    |> Task.yield()
  end
end
