defmodule Notifications.Workers.Slack.Message do
  def construct(channel, %{
        pipeline: pipeline,
        project: project,
        hook: hook,
        organization: organization
      }) do
    color = color(pipeline.result)
    author = hook.repo_host_username

    base_domain = Application.fetch_env!(:notifications, :domain)

    workflow_url =
      "https://#{organization.org_username}.#{base_domain}/workflows/#{pipeline.wf_id}?pipeline_id=#{pipeline.ppl_id}"

    commit_msg = String.slice(hook.commit_message, 0..50)
    commit_url = "#{hook.repo_host_url}/commit/#{hook.head_commit_sha}"
    commit_sha = String.slice(hook.head_commit_sha, 0..8)
    result = pipeline.result |> Atom.to_string() |> String.downcase()
    project_name = project.metadata.name
    pipeline_name = pipeline.name
    branch_name = pipeline.branch_name

    %{
      "username" => "Semaphore",
      "icon_url" => "https://a.slack-edge.com/7f1a0/plugins/semaphore/assets/service_72.png",
      "channel" => channel,
      "attachments" => [
        %{
          "color" => color,
          "fallback" =>
            "#{author}'s <#{workflow_url}|#{pipeline_name}> #{result} — #{commit_msg}",
          "text" =>
            "#{author}'s <#{workflow_url}|#{pipeline_name}> #{result} — <#{commit_url}|#{commit_sha}> #{commit_msg} on #{branch_name}",
          "author_name" => project_name
        }
      ]
    }
  end

  defp color(:PASSED), do: "#19a974"
  defp color(_), do: "#f75819"
end
