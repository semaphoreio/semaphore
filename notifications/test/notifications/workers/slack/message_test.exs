defmodule Notifications.Workers.Slack.MessageTest do
  use Notifications.DataCase

  alias Notifications.Workers.Slack.Message

  describe ".construct" do
    test "constructs a message" do
      channel = "#dev-null"

      project = Support.Factories.Project.build()
      workflow = Support.Factories.Workflow.build(project)

      data = %{
        project: project,
        pipeline: Support.Factories.Pipeline.build(project, workflow),
        blocks: [Support.Factories.Block.build()],
        hook: Support.Factories.Hook.build(),
        organization: Support.Factories.Organization.build(),
        workflow: workflow
      }

      expected_message = %{
        "attachments" => [
          %{
            "author_name" => "test-repo",
            "color" => "#f75819",
            "fallback" =>
              "test-username's <https://ribizzla.testing.com/workflows/?pipeline_id=#{data[:pipeline].ppl_id}|Build & Test> failed — Update README.md",
            "text" =>
              "test-username's <https://ribizzla.testing.com/workflows/?pipeline_id=#{data[:pipeline].ppl_id}|Build & Test> failed — <https://github.com/test/test-repo/commit/273b85fbebf7a9493af8c4102d40eb059c9fc6e7|273b85fbe> Update README.md on master"
          }
        ],
        "channel" => "#dev-null",
        "icon_url" => "https://a.slack-edge.com/7f1a0/plugins/semaphore/assets/service_72.png",
        "username" => "Semaphore"
      }

      assert Message.construct(channel, data) == expected_message
    end

    test "constructs a message from the pipeline when the hook is missing" do
      project = Support.Factories.Project.build()
      workflow = Support.Factories.Workflow.build(project)

      pipeline = %{
        Support.Factories.Pipeline.build(project, workflow)
        | commit_message: "Nightly build"
      }

      data = %{
        project: project,
        pipeline: pipeline,
        blocks: [Support.Factories.Block.build()],
        hook: nil,
        organization: Support.Factories.Organization.build(),
        workflow: workflow
      }

      workflow_link =
        "<https://ribizzla.testing.com/workflows/?pipeline_id=#{pipeline.ppl_id}|Build & Test>"

      assert %{"attachments" => [attachment], "channel" => "#dev-null"} =
               Message.construct("#dev-null", data)

      assert attachment["author_name"] == "test-repo"
      assert attachment["fallback"] == "#{workflow_link} failed — Nightly build"
      assert attachment["text"] == "#{workflow_link} failed — 273b85fbe Nightly build on master"
    end
  end
end
