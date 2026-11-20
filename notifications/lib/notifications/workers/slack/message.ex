defmodule Notifications.Workers.Slack.Message do
  def construct(channel, %{
        pipeline: pipeline,
        project: project,
        hook: hook,
        organization: organization
      }) do
    color = color(pipeline.result)
    author = author(hook)

    base_domain = Application.fetch_env!(:notifications, :domain)

    workflow_url =
      "https://#{organization.org_username}.#{base_domain}/workflows/#{pipeline.wf_id}?pipeline_id=#{pipeline.ppl_id}"

    commit_msg = String.slice(commit_message(pipeline, hook), 0..50)
    commit = commit(pipeline, hook)
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
          "fallback" => "#{author}<#{workflow_url}|#{pipeline_name}> #{result} — #{commit_msg}",
          "text" =>
            "#{author}<#{workflow_url}|#{pipeline_name}> #{result} — #{commit} #{commit_msg} on #{branch_name}",
          "author_name" => project_name
        }
      ]
    }
  end

  # Without a hook there is no author or repository URL, only the pipeline's commit.
  defp author(nil), do: ""
  defp author(hook), do: "#{hook.repo_host_username}'s "

  defp commit_message(pipeline, nil), do: pipeline.commit_message
  defp commit_message(_pipeline, hook), do: hook.commit_message

  defp commit(pipeline, nil), do: String.slice(pipeline.commit_sha, 0..8)

  defp commit(_pipeline, hook) do
    "<#{hook.repo_host_url}/commit/#{hook.head_commit_sha}|#{String.slice(hook.head_commit_sha, 0..8)}>"
  end

  defp color(:PASSED), do: "#19a974"
  defp color(_), do: "#f75819"
end
