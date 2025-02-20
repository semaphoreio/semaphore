defmodule GithubNotifier.Notifier do
  alias GithubNotifier.TaskSupervisor
  alias GithubNotifier.Models

  def notify(request_id, pipeline_id, block_id \\ nil) do
    {:ok, pipeline} = fetch_pipeline(pipeline_id)
    {:ok, repo_proxy} = fetch_repo_proxy(pipeline.hook_id)
    {:ok, project} = fetch_project(pipeline.project_id)

    case project do
      nil ->
        nil

      project ->
        data = GithubNotifier.Extractor.extract(pipeline, block_id, repo_proxy, project)
        GithubNotifier.Status.create(data, request_id)
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
