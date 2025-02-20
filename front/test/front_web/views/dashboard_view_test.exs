defmodule FrontWeb.DashboardViewTest do
  use FrontWeb.ConnCase

  setup do
    Cacheman.clear(:front)
    Support.FakeServices.stub_responses()
  end

  describe ".workflow_widget_title" do
    test "when the workflow and repo proxy api include tag and pull request" do
      params = [
        page_size: 10,
        page_token: "",
        created_after: %Google.Protobuf.Timestamp{nanos: 0, seconds: 1_606_236_838},
        organization_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
        direction: 0,
        requester_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
        project_ids: []
      ]

      {wfs, _next_page_token, _previous_page_token} = Front.Models.Workflow.list_keyset(params)
      workflows = Front.Decorators.Workflow.decorate_many(wfs)

      workflow_widget_titles =
        Enum.map(workflows, fn w -> FrontWeb.DashboardView.workflow_widget_title(w) end)

      require Logger
      Logger.error(inspect(workflows))
      assert workflow_widget_titles == ["v1.2.3", "dummy pr"]
    end

    test "when the workflow is triggered by tag event" do
      decorated_workflow = %Front.Decorators.Workflow{
        author_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
        author_name: "jane",
        branch_name: "master",
        hook_name: "v1.2.3",
        hook_url: "/branches/2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        name: "Pull new workflows on the branch page",
        pr_mergeable: false,
        pr_number: "5",
        project_url: "/projects/clean-code-javascript",
        tag_name: "v1.2.3",
        type: "tag"
      }

      assert FrontWeb.DashboardView.workflow_widget_title(decorated_workflow) == "v1.2.3"
    end

    test "when the workflow is triggered on pull request" do
      decorated_workflow = %Front.Decorators.Workflow{
        author_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
        author_name: "octocat",
        branch_name: "master",
        hook_name: "dummy pr",
        hook_url: "/branches/2cb61a21-c759-4d50-a45a-1e1eaba8c1bf",
        name: "dummy pr",
        pr_mergeable: true,
        pr_number: "8",
        project_url: "/projects/clean-code-javascript",
        tag_name: "",
        type: "pr"
      }

      assert FrontWeb.DashboardView.workflow_widget_title(decorated_workflow) == "dummy pr"
    end

    test "when the workflow is triggered for a regular branch push" do
      decorated_workflow = %Front.Decorators.Workflow{
        author_avatar_url: "https://avatars1.githubusercontent.com/u/74402801?v=4",
        author_name: "horace-stavropoulos",
        branch_name: "cleanup-bucket-lock",
        hook_name: "cleanup-bucket-lock",
        hook_url: "/branches/fa2a4a44-45f1-481d-aa24-2acc49a7973c",
        name: "Added debug message for locked-skipped cleanup",
        pr_mergeable: false,
        pr_number: "",
        project_url: "/projects/artifacthub",
        tag_name: "",
        type: "branch"
      }

      assert FrontWeb.DashboardView.workflow_widget_title(decorated_workflow) ==
               "cleanup-bucket-lock"
    end
  end
end
