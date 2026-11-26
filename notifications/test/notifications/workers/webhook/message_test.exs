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

    test "fills the tag for a tag hook" do
      hook = %{
        Support.Factories.Hook.build()
        | git_ref_type: :TAG,
          git_ref: "refs/tags/v1.2.0",
          tag_name: "v1.2.0"
      }

      revision = Message.construct(build_data(hook))["revision"]

      assert revision["reference"] == "refs/tags/v1.2.0"
      assert revision["reference_type"] == "tag"
      assert revision["tag"] == %{"name" => "v1.2.0"}
      assert revision["branch"] == nil
      assert revision["pull_request"] == nil
      assert revision["sender"]["login"] == "test-username"
    end

    test "fills the pull request for a pull request hook" do
      hook = %{
        Support.Factories.Hook.build()
        | git_ref_type: :PR,
          pr_slug: "contributor/test-repo",
          pr_number: "12",
          pr_name: "Fix the build",
          pr_sha: "4f1b2c3d",
          pr_branch_name: "fix-build",
          commit_range: "1a2b...4f1b"
      }

      revision = Message.construct(build_data(hook))["revision"]

      assert revision["reference_type"] == "pull_request"

      assert revision["pull_request"] == %{
               "head_repo_slug" => "contributor/test-repo",
               "number" => "12",
               "name" => "Fix the build",
               "head_sha" => "4f1b2c3d",
               "branch_name" => "fix-build",
               "commit_range" => "1a2b...4f1b"
             }

      assert revision["branch"] == nil
      assert revision["tag"] == nil
    end

    test "builds the revision from a branch pipeline when the hook is missing" do
      data = build_data(nil)
      message = Message.construct(data)

      assert message["repository"] == %{"slug" => "", "url" => ""}

      assert message["revision"] == %{
               "reference" => "refs/heads/master",
               "reference_type" => "branch",
               "commit_sha" => "273b85fbebf7a9493af8c4102d40eb059c9fc6e7",
               "commit_message" => "Nightly build",
               "sender" => %{"login" => "", "email" => "", "avatar_url" => ""},
               "branch" => %{"name" => "master", "commit_range" => ""},
               "pull_request" => nil,
               "tag" => nil
             }

      assert message["pipeline"]["id"] == data.pipeline.ppl_id
      assert message["project"]["name"] == "test-repo"
    end

    test "builds the revision from a tag pipeline when the hook is missing" do
      data = build_data(nil)
      data = %{data | pipeline: %{data.pipeline | branch_name: "refs/tags/v1.2.0"}}

      revision = Message.construct(data)["revision"]

      assert revision["reference"] == "refs/tags/v1.2.0"
      assert revision["reference_type"] == "tag"
      assert revision["tag"] == %{"name" => "v1.2.0"}
      assert revision["branch"] == nil
      assert revision["commit_message"] == "Nightly build"
    end
  end

  defp build_data(hook) do
    project = Support.Factories.Project.build()
    workflow = Support.Factories.Workflow.build(project)

    pipeline = %{
      Support.Factories.Pipeline.build(project, workflow)
      | commit_message: "Nightly build"
    }

    %{
      organization: Support.Factories.Organization.build(),
      project: project,
      workflow: workflow,
      pipeline: pipeline,
      blocks: [Support.Factories.Block.build()],
      hook: hook
    }
  end
end
