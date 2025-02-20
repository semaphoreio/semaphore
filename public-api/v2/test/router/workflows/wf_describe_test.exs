defmodule Router.Workflows.DescribeTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [describe_wf: 2]

  describe "authorized users" do
    setup do
      Support.Stubs.reset()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project.id)

      {:ok, %{project_id: project.id, org_id: org_id, user_id: user_id}}
    end

    test "GET /workflows/:wf_id - endpoint returns 200", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      _ = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      assert {200, _} = describe_wf(workflow.id, ctx)
    end

    test "GET /workflows/:wf_id - non-existing wf_id - authorization failure", ctx do
      uuid = UUID.uuid4()
      assert {404, message} = describe_wf(uuid, ctx)
      assert %{"message" => "Pipeline not found", "documentation_url" => _} = message

      assert {422, message} = describe_wf("does-not-exist", ctx)
      assert %{"message" => "Validation Failed"} = message
    end

    test "GET /workflows/:wf_id - not owned by the requester org", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      _ = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      GrpcMock.stub(WorkflowMock, :describe, fn _req, _ ->
        alias InternalApi.PlumberWF.DescribeResponse
        # workflow = workflow.api_model
        %DescribeResponse{
          status: %InternalApi.Status{},
          workflow: %{workflow.api_model | project_id: UUID.uuid4()}
        }
      end)

      assert {404, message} = describe_wf(workflow.id, ctx)
      assert %{"message" => "Not found"} = message
    end
  end

  describe "unauthorized users" do
    setup do
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      {:ok, %{project_id: project.id, org_id: org_id, user_id: user_id}}
    end

    test "GET /workflows/:wf_id - unauthorized user", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      _ = Support.Stubs.Pipeline.create_initial(workflow)
      assert {404, message} = describe_wf(workflow.id, ctx)
      assert %{"message" => "Project not found"} = message
    end
  end
end
