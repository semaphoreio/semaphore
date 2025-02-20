defmodule Router.PartialRebuildTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [post_partial_rebuild: 4, describe_ppl_with_id: 2]

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project.id)
      PermissionPatrol.add_permissions(org_id, user_id, "project.job.rerun", project.id)

      {:ok, %{project_id: project.id, org_id: org_id, user_id: user_id}}
    end

    test "POST /pipelines/:pipeline_id/partial_rebuild - valid args", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      Support.Stubs.Pipeline.change_state(pipeline.id, :failed)

      assert %{"pipeline_id" => ppl_id} =
               post_partial_rebuild(pipeline.id, ctx, %{"request_token" => UUID.uuid4()}, 200)

      assert {:ok, _} = UUID.info(ppl_id)
    end

    test "POST /pipelines/:pipeline_id/partial_rebuild - pipeline in state done and result passed",
         ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      Support.Stubs.Pipeline.change_state(pipeline.id, :passed)

      resp = post_partial_rebuild(pipeline.id, ctx, %{"request_token" => UUID.uuid4()}, 400)
      assert resp == "Pipelines which passed can not be partial rebuilt."
    end

    test "POST /pipelines/:pipeline_id/partial_rebuild - not in state done", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      Support.Stubs.Pipeline.change_state(pipeline.id, :running)

      assert {200, response} = describe_ppl_with_id(pipeline.id, ctx)
      assert %{"pipeline" => %{"state" => state}} = response
      assert state != "done"

      resp = post_partial_rebuild(pipeline.id, ctx, %{"request_token" => UUID.uuid4()}, 400)
      assert resp == "Only pipelines which are in done state can be partial rebuilt."
    end

    test "POST /pipelines/:pipeline_id/partial_rebuild -request token empty", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      Support.Stubs.Pipeline.change_state(pipeline.id, :failed)

      assert {200, _response} = describe_ppl_with_id(pipeline.id, ctx)

      resp = post_partial_rebuild(pipeline.id, ctx, %{"request_token" => ""}, 400)
      assert resp == "Missing required post parameter request_token."
    end

    test "Unauthorized access to pipeline by non-owner should be denied", ctx do
      user_id = UUID.uuid4()
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, user_id)
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      GrpcMock.stub(PipelineMock, :describe, fn _req, _opts ->
        alias Support.Stubs.DB
        alias InternalApi.Plumber.DescribeResponse

        ppl = DB.find(:pipelines, pipeline.id)
        code = InternalApi.Plumber.ResponseStatus.ResponseCode.value(:OK)
        status = %InternalApi.Plumber.ResponseStatus{code: code, message: ""}

        %DescribeResponse{
          response_status: status,
          pipeline: %{ppl.api_model | project_id: UUID.uuid4()},
          blocks: []
        }
      end)

      args = %{"request_token" => UUID.uuid4()}

      assert %{"message" => "Not Found"} = post_partial_rebuild(pipeline.id, ctx, args, 404)
    end
  end
end
