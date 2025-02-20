defmodule Notifications.Workers.Webhook.MessageTest do
  use Notifications.DataCase

  alias Notifications.Workers.Webhook.Message

  describe ".construct" do
    test "constructs a message" do
      org = Support.Factories.Organization.build()
      project = Support.Factories.Project.build()
      workflow = Support.Factories.Workflow.build(project)
      pipeline = Support.Factories.Pipeline.build(project, workflow)
      block = Support.Factories.Block.build()

      data = %{
        organization: org,
        project: project,
        workflow: workflow,
        pipeline: pipeline,
        blocks: [block],
        hook: Support.Factories.Hook.build()
      }

      expected_message = %{
        "blocks" => [
          %{
            "jobs" => [
              %{
                "id" => hd(block.jobs).job_id,
                "index" => 0,
                "name" => "Rspec 1",
                "result" => "stopped",
                "status" => "finished"
              }
            ],
            "name" => "Rspec",
            "result" => "passed",
            "result_reason" => "test",
            "state" => "done"
          }
        ],
        "organization" => %{
          "id" => org.org_id,
          "name" => "ribizzla"
        },
        "pipeline" => %{
          "created_at" => "1970-01-01T00:00:01Z",
          "done_at" => "1970-01-01T00:00:01Z",
          "error_description" => "",
          "id" => pipeline.ppl_id,
          "name" => "Build & Test",
          "pending_at" => "1970-01-01T00:00:01Z",
          "queuing_at" => "1970-01-01T00:00:01Z",
          "result" => "failed",
          "result_reason" => "test",
          "running_at" => "1970-01-01T00:00:01Z",
          "state" => "running",
          "stopping_at" => nil,
          "working_directory" => ".semaphore",
          "yaml_file_name" => "semaphore.yml"
        },
        "project" => %{
          "id" => project.metadata.id,
          "name" => "test-repo"
        },
        "repository" => %{
          "url" => "https://github.com/test/test-repo",
          "slug" => ""
        },
        "revision" => %{
          "branch" => %{
            "name" => "",
            "commit_range" => ""
          },
          "pull_request" => nil,
          "reference" => "",
          "reference_type" => "branch",
          "sender" => %{
            "avatar_url" => "",
            "email" => "test@test.com",
            "login" => "test-username"
          },
          "tag" => nil,
          "commit_message" => "Update README.md",
          "commit_sha" => "273b85fbebf7a9493af8c4102d40eb059c9fc6e7"
        },
        "workflow" => %{
          "created_at" => "1970-01-01T00:00:01Z",
          "id" => workflow.wf_id,
          "initial_pipeline_id" => pipeline.ppl_id
        },
        "version" => "1.0.0"
      }

      assert Message.construct(data) == expected_message
    end
  end
end
