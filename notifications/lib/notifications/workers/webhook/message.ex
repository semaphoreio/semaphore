defmodule Notifications.Workers.Webhook.Message do
  def construct(%{
        workflow: workflow,
        pipeline: pipeline,
        blocks: blocks,
        project: project,
        hook: hook,
        organization: organization
      }) do
    reference_type = reference_type(hook.git_ref_type)

    %{
      "version" => "1.0.0",
      "organization" => %{
        "name" => organization.org_username,
        "id" => organization.org_id
      },
      "project" => %{
        "name" => project.metadata.name,
        "id" => project.metadata.id
      },
      "repository" => %{
        "slug" => hook.repo_slug,
        "url" => hook.repo_host_url
      },
      "revision" => %{
        "reference" => hook.git_ref,
        "reference_type" => reference_type,
        "commit_sha" => hook.head_commit_sha,
        "commit_message" => hook.commit_message,
        "sender" => %{
          "login" => hook.repo_host_username,
          "email" => hook.repo_host_email,
          "avatar_url" => hook.repo_host_avatar_url
        },
        "branch" => branch(reference_type, hook),
        "pull_request" => pull_request(reference_type, hook),
        "tag" => tag(reference_type, hook)
      },
      "workflow" => %{
        "id" => workflow.wf_id,
        "initial_pipeline_id" => workflow.initial_ppl_id,
        "created_at" => format_time(workflow.created_at)
      },
      "pipeline" => %{
        "id" => pipeline.ppl_id,
        "yaml_file_name" => pipeline.yaml_file_name,
        "working_directory" => pipeline.working_directory,
        "state" => map_state_to_string(pipeline.state),
        "result_reason" => map_result_reason_to_string(pipeline.result_reason),
        "result" => map_result_to_string(pipeline.result),
        "name" => pipeline.name,
        "error_description" => pipeline.error_description,
        "running_at" => format_time(pipeline.running_at),
        "queuing_at" => format_time(pipeline.queuing_at),
        "pending_at" => format_time(pipeline.pending_at),
        "stopping_at" => format_time(pipeline.stopping_at),
        "done_at" => format_time(pipeline.done_at),
        "created_at" => format_time(pipeline.created_at)
      },
      "blocks" =>
        Enum.map(blocks, fn block ->
          %{
            "state" => map_block_state_to_string(block.state),
            "result" => map_block_result_to_string(block.result),
            "result_reason" => map_block_result_reason_to_string(block.result_reason),
            "name" => block.name,
            "jobs" =>
              Enum.map(block.jobs, fn job ->
                %{
                  "id" => job.job_id,
                  "name" => job.name,
                  "index" => job.index,
                  "status" => job.status |> String.downcase(),
                  "result" => job.result |> String.downcase()
                }
              end)
          }
        end)
    }
  end

  defp reference_type(git_ref_type) do
    case downcase_atom(git_ref_type) do
      "pr" -> "pull_request"
      ref -> ref
    end
  end

  defp branch("branch", hook) do
    %{
      "name" => hook.branch_name,
      "commit_range" => hook.commit_range
    }
  end

  defp branch(_, _), do: nil

  defp pull_request("pull_request", hook) do
    %{
      "head_repo_slug" => hook.pr_slug,
      "number" => hook.pr_number,
      "name" => hook.pr_name,
      "head_sha" => hook.pr_sha,
      "branch_name" => hook.pr_branch_name,
      "commit_range" => hook.commit_range
    }
  end

  defp pull_request(_, _), do: nil

  defp tag("tag", hook) do
    %{
      "name" => hook.tag_name
    }
  end

  defp tag(_, _), do: nil

  def map_block_result_reason_to_string(enum), do: downcase_atom(enum)
  def map_block_state_to_string(enum), do: downcase_atom(enum)
  def map_block_result_to_string(enum), do: downcase_atom(enum)
  def map_result_reason_to_string(enum), do: downcase_atom(enum)
  def map_result_to_string(enum), do: downcase_atom(enum)
  def map_state_to_string(:INITIALIZING), do: "passed"
  def map_state_to_string(enum), do: downcase_atom(enum)

  defp format_time(nil), do: nil
  defp format_time(%{seconds: nil}), do: nil

  defp format_time(google_timestamp) do
    google_timestamp.seconds
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
  end

  defp downcase_atom(atom), do: atom |> Atom.to_string() |> String.downcase()
end
