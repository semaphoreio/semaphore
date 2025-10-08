defmodule Front.Models.WorkflowTest do
  use Front.TestCase

  alias Front.Models.Workflow
  alias Support.FakeServices, as: FS
  alias Support.Stubs.DB
  @branch_id "8b74608d-bbbb-4d4e-a3e4-8b74608dcc1c"
  @hook_id "8b74608d-hhhh-4d4e-a3e4-8b74608dcc1c"
  @project_id "8b74608d-pppp-4d4e-a3e4-8b74608dcc1c"
  @workflow_id "8b74608d-wwww-4d4e-a3e4-8b74608dcc1c"

  setup do
    Support.FakeServices.stub_responses()

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()
  end

  describe ".find" do
    test "returns the wanted workflow" do
      workflow = DB.first(:workflows)

      found_workflow = Workflow.find(workflow.id)

      assert found_workflow.id == workflow.id
      assert found_workflow.branch_name == "master"
    end

    test "when the workflow is not found => returns nil" do
      workflow_describe_response =
        InternalApi.PlumberWF.DescribeResponse.new(
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:NOT_FOUND),
            message: ""
          }
        )

      GrpcMock.stub(WorkflowMock, :describe, workflow_describe_response)

      refute Workflow.find("123")
    end

    test "when the workflow request had a failed precondition => returns nil" do
      workflow_describe_response =
        InternalApi.PlumberWF.DescribeResponse.new(
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
            message: ""
          }
        )

      GrpcMock.stub(WorkflowMock, :describe, workflow_describe_response)
      refute Workflow.find("123")
    end

    test "when there is another result error on the backend => raises an error" do
      assert_raise CaseClauseError, fn ->
        workflow_describe_response =
          InternalApi.PlumberWF.DescribeResponse.new(
            status: %InternalApi.Status{
              code: Google.Rpc.Code.value(:UNKNOWN),
              message: ""
            }
          )

        GrpcMock.stub(WorkflowMock, :describe, workflow_describe_response)

        Workflow.find("123")
      end
    end
  end

  describe ".find_many" do
    test "returns the wanted workflows" do
      workflow = DB.first(:workflows)

      [found_workflow] = Workflow.find_many([workflow.id])

      assert found_workflow.id == workflow.id
      assert found_workflow.branch_name == "master"
    end

    test "when the workflow is not found => returns empty list" do
      workflow_describe_response =
        InternalApi.PlumberWF.DescribeManyResponse.new(
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:NOT_FOUND),
            message: ""
          }
        )

      GrpcMock.stub(WorkflowMock, :describe_many, workflow_describe_response)

      assert Enum.empty?(Workflow.find_many(["123"]))
    end

    test "when the workflow request had a failed precondition => returns empty list" do
      workflow_describe_response =
        InternalApi.PlumberWF.DescribeManyResponse.new(
          status: %InternalApi.Status{
            code: Google.Rpc.Code.value(:FAILED_PRECONDITION),
            message: ""
          }
        )

      GrpcMock.stub(WorkflowMock, :describe_many, workflow_describe_response)
      assert Enum.empty?(Workflow.find_many(["123"]))
    end

    test "when there is another result error on the backend => raises an error" do
      assert_raise CaseClauseError, fn ->
        workflow_describe_response =
          InternalApi.PlumberWF.DescribeManyResponse.new(
            status: %InternalApi.Status{
              code: Google.Rpc.Code.value(:UNKNOWN),
              message: ""
            }
          )

        GrpcMock.stub(WorkflowMock, :describe_many, workflow_describe_response)

        Workflow.find_many(["123"])
      end
    end
  end

  describe ".find_latest" do
    test "returns last created workflow from the list of workflows" do
      workflow = Support.Factories.workflow()

      workflow_list_response =
        InternalApi.PlumberWF.ListResponse.new(
          workflows: [workflow],
          status: Support.Factories.internal_api_status_ok(),
          page_number: 1,
          total_pages: 1
        )

      GrpcMock.stub(WorkflowMock, :list, workflow_list_response)
      FunRegistry.set!(FS.RepoProxyService, :describe, sample_hook())

      assert Workflow.find_latest(project_id: "123", branch_name: "master") ==
               Workflow.construct(workflow)
    end

    test "returns nil when there are no workflows on the branch" do
      workflow_list_response =
        InternalApi.PlumberWF.ListResponse.new(
          workflows: [],
          status: Support.Factories.internal_api_status_ok(),
          page_number: 1,
          total_pages: 1
        )

      GrpcMock.stub(WorkflowMock, :list, workflow_list_response)

      assert Workflow.find_latest(project_id: "123", branch_name: "master") == nil
    end
  end

  describe ".preload_commit_data" do
    test "adds hook data to the workflow" do
      workflow = %Front.Models.Workflow{
        author_avatar_url: nil,
        author_name: nil,
        branch_id: @branch_id,
        branch_name: "ms/describing-preloading-commit-data",
        commit_message: nil,
        commit_sha: "61aa054eb26b27236bf1862d14b004ca2474bef7",
        git_ref_type: nil,
        github_commit_url: nil,
        hook_id: @hook_id,
        id: @workflow_id,
        project_id: @project_id
      }

      FunRegistry.set!(FS.RepoProxyService, :describe_many, sample_hook())

      wf_with_hook_info = Workflow.preload_commit_data(workflow)

      assert wf_with_hook_info.hook.name == "ms/describing-preloading-commit-data"
    end
  end

  describe "caching with TTL" do
    test "sets 2-hour TTL when workflow has active pipelines" do
      workflow = DB.first(:workflows)
      Cacheman.delete(:front, "workflow:#{workflow.id}")
      workflow_with_running_pipeline = %{workflow | state: :RUNNING}

      workflow_describe_response =
        InternalApi.PlumberWF.DescribeResponse.new(
          workflow: workflow_with_running_pipeline,
          status: Support.Factories.internal_api_status_ok()
        )

      GrpcMock.stub(WorkflowMock, :describe, workflow_describe_response)

      found_workflow = Workflow.find(workflow.id)

      {:ok, ttl} = Cacheman.ttl(:front, "workflow:#{workflow.id}")
      # TTL should be approximately 2 hours (7200 seconds), allow some variance
      assert ttl > 7000 and ttl <= 7200
    end

    test "sets infinite TTL when workflow has no active pipelines" do
      workflow = DB.first(:workflows)
      Cacheman.delete(:front, "workflow:#{workflow.id}")
      workflow_completed = %{workflow | state: :DONE}

      workflow_describe_response =
        InternalApi.PlumberWF.DescribeResponse.new(
          workflow: workflow_completed,
          status: Support.Factories.internal_api_status_ok()
        )

      GrpcMock.stub(WorkflowMock, :describe, workflow_describe_response)

      found_workflow = Workflow.find(workflow.id)

      {:ok, ttl} = Cacheman.ttl(:front, "workflow:#{workflow.id}")
      assert ttl == :infinity
    end
  end

  defp sample_hook do
    %InternalApi.RepoProxy.DescribeResponse{
      hook: %InternalApi.RepoProxy.Hook{
        branch_name: "ms/describing-preloading-commit-data",
        commit_message: "wip",
        commit_author: "radwo",
        commit_range:
          "e2f9050bddc171648cdb62ed187d74f03641c3f8...2d3e89c103a72ef950f1e5866c6df8917a747fdb",
        git_ref: "refs/heads/ms/describing-preloading-commit-data",
        git_ref_type: 0,
        head_commit_sha: "2d3e89c103a72ef950f1e5866c6df8917a747fdb",
        hook_id: @hook_id,
        pr_mergeable: false,
        pr_name: "",
        pr_branch_name: "master",
        pr_number: "",
        pr_sha: "",
        pr_slug: "",
        repo_host_avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
        repo_host_email: "octocat@github.com",
        repo_host_url: "https://github.com/octocat/front",
        repo_host_username: "octocat",
        repo_slug: "octocat/front",
        repo_host_uid: "",
        semaphore_email: "",
        tag_name: "",
        user_id: "test"
      },
      status: %InternalApi.ResponseStatus{code: 0, message: ""}
    }
  end
end
