defmodule Front.Decorators.Workflow do
  require Logger

  defstruct [
    :id,
    :short_commit_id,
    :github_commit_url,
    :commit_message,
    :branch_id,
    :project_id,
    :root_pipeline_id,
    :hook_id,
    :requester_id,
    :requester,
    :hook,
    :git_ref_type,
    :commit_sha,
    :triggered_by,
    :rerun_of,
    :type,
    :name,
    :url,
    :hook_name,
    :hook_url,
    :project_name,
    :project_url,
    :author_name,
    :author_avatar_url,
    :pipelines,
    :created_at,
    :pr_number,
    :pr_mergeable,
    :tag_name,
    :branch_name,
    :summary
  ]

  def decorate_one(nil), do: nil
  def decorate_one(workflow), do: construct(workflow)

  def decorate_many(workflows) do
    workflows
    |> Enum.map(&construct/1)
  end

  def decorate_with_pipelines(pipelines) do
    {:ok, stream_supervisor} = Task.Supervisor.start_link()

    stream_supervisor
    |> Task.Supervisor.async_stream(
      pipelines,
      fn pipeline ->
        workflow = Front.Models.Workflow.find(pipeline.workflow_id)
        %{workflow | pipelines: [pipeline]}
      end,
      ordered: false,
      max_concurrency: 5
    )
    |> Enum.map(fn
      {:ok, workflow} -> workflow
      _ -> nil
    end)
    |> Enum.filter(& &1)
    |> decorate_many()
  end

  # this clause is used for JustRun pipelines
  # that didn't succeed in creating a hook
  defp construct(workflow = %{hook: nil}) do
    %__MODULE__{
      id: workflow.id,
      short_commit_id: workflow.short_commit_id,
      github_commit_url: workflow.github_commit_url,
      commit_message: workflow.commit_message,
      branch_id: workflow.branch_id,
      project_id: workflow.project_id,
      root_pipeline_id: workflow.root_pipeline_id,
      hook_id: workflow.hook_id,
      requester_id: workflow.requester_id,
      requester: workflow.requester,
      hook: workflow.hook,
      git_ref_type: workflow.git_ref_type,
      commit_sha: workflow.commit_sha,
      triggered_by: workflow.triggered_by,
      rerun_of: workflow.rerun_of,
      type: "branch",
      name: "Unsuccessful task execution",
      url: url(workflow),
      hook_name: workflow.branch_name,
      hook_url: hook_url(workflow),
      project_name: workflow.project_name,
      project_url: project_url(workflow),
      author_name: author_name(workflow),
      author_avatar_url: author_avatar_url(workflow),
      pipelines: sort_by_done_at(workflow.pipelines),
      created_at: workflow.created_at,
      pr_number: "",
      pr_mergeable: "",
      tag_name: "",
      branch_name: workflow.branch_name,
      summary: workflow.summary
    }
  end

  defp construct(workflow) do
    %__MODULE__{
      id: workflow.id,
      short_commit_id: workflow.short_commit_id,
      github_commit_url: workflow.github_commit_url,
      commit_message: workflow.commit_message,
      branch_id: workflow.branch_id,
      project_id: workflow.project_id,
      root_pipeline_id: workflow.root_pipeline_id,
      hook_id: workflow.hook_id,
      requester_id: workflow.requester_id,
      requester: workflow.requester,
      hook: workflow.hook,
      git_ref_type: workflow.git_ref_type,
      commit_sha: workflow.commit_sha,
      triggered_by: workflow.triggered_by,
      rerun_of: workflow.rerun_of,
      type: workflow.hook.type,
      name: name(workflow),
      url: url(workflow),
      hook_name: workflow.hook.name,
      hook_url: hook_url(workflow),
      project_name: workflow.project_name,
      project_url: project_url(workflow),
      author_name: author_name(workflow),
      author_avatar_url: author_avatar_url(workflow),
      pipelines: sort_by_done_at(workflow.pipelines),
      created_at: workflow.created_at,
      pr_number: workflow.hook.pr_number,
      pr_mergeable: workflow.hook.pr_mergeable,
      tag_name: workflow.hook.tag_name,
      branch_name: workflow.hook.branch_name,
      summary: workflow.summary
    }
  end

  def hook_url(workflow) do
    "/branches/#{workflow.branch_id}"
  end

  def project_url(workflow) do
    "/projects/#{workflow.project_name}"
  end

  def name(workflow) do
    hd(workflow.hook.commit_message |> String.split("\n"))
  end

  def url(workflow) do
    "/workflows/#{workflow.id}?pipeline_id=#{workflow.root_pipeline_id}"
  end

  def author_name(workflow) do
    case workflow.triggered_by do
      :HOOK -> workflow.hook.repo_host_username
      :SCHEDULE -> "scheduler"
      :API -> workflow.requester.name
      :MANUAL_RUN -> workflow.requester.name
    end
  rescue
    _ ->
      Logger.error("Failed to get author_name for workflow, using default instead as a fallback")
      Logger.error(inspect(workflow))

      Application.get_env(:front, :default_user_name)
  end

  def author_avatar_url(workflow) do
    case workflow.triggered_by do
      :HOOK -> workflow.hook.repo_host_avatar_url
      :SCHEDULE -> "#{FrontWeb.SharedHelpers.assets_path()}/images/profile-bot.svg"
      :API -> workflow.requester.avatar_url
      :MANUAL_RUN -> workflow.requester.avatar_url
    end
  rescue
    _ ->
      Logger.error("Failed to get avatar_url for workflow, using default instead as a fallback")
      Logger.error(inspect(workflow))

      "#{FrontWeb.SharedHelpers.assets_path()}/images/semaphore-logo-sign-black.svg"
  end

  def sort_by_done_at(pipelines) do
    Enum.sort_by(pipelines, fn p -> p.timeline.done_at end)
  end
end
