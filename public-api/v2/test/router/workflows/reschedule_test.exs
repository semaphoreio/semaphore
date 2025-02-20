defmodule Router.Workflows.RescheduleTest do
  use PublicAPI.Case
  import Test.PipelinesClient, only: [post_reschedule: 4]

  describe "naive authorization filter with default allowed users" do
    setup do
      Support.Stubs.reset()

      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project_id)
      PermissionPatrol.add_permissions(org_id, user_id, "project.job.rerun", project_id)

      {:ok, %{project_id: project_id, org_id: org_id, user_id: user_id}}
    end

    test "POST /workflows/:wf_id/reschedule - valid args", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      _ = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      response = post_reschedule(workflow.id, ctx, %{"request_token" => UUID.uuid4()}, 200)
      assert %{"wf_id" => wf_id, "ppl_id" => ppl_id} = response
      assert {:ok, _} = UUID.info(ppl_id)
      assert {:ok, _} = UUID.info(wf_id)
    end

    test "POST /workflows/:wf_id/reschedule - wrong wf_id", ctx do
      response = post_reschedule("123", ctx, %{"request_token" => UUID.uuid4()}, 422)
      assert %{"message" => "Validation Failed"} = response
    end

    test "POST /workflows/:wf_id/reschedule - request token missing", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      _ = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      response = post_reschedule(workflow.id, ctx, %{"request_token" => ""}, 422)
      assert %{"message" => "Validation Failed"} = response
    end

    test "POST /workflows/:wf_id/reschedule - workflow not owned by requester org -> 404", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      _ = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      GrpcMock.stub(WorkflowMock, :describe, fn _req, _ ->
        alias InternalApi.PlumberWF.DescribeResponse

        %DescribeResponse{
          status: %InternalApi.Status{},
          workflow: %{workflow.api_model | project_id: UUID.uuid4()}
        }
      end)

      response = post_reschedule(workflow.id, ctx, %{"request_token" => UUID.uuid4()}, 404)

      assert %{"message" => "Not found"} = response
    end
  end
end
