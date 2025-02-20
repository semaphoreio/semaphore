defmodule Router.DescribeTest do
  alias Support.Stubs.DB
  use PublicAPI.Case

  import Test.PipelinesClient,
    only: [
      describe_ppl_with_id: 2,
      describe_ppl_with_id: 4
    ]

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project.id)

      {:ok, %{project_id: project.id, org_id: org_id, user_id: user_id}}
    end

    # Response id 404 - Not Found due to failed authorization
    test "GET /pipelines/:ppl_id - non-existing ppl_id - authorization failure", ctx do
      uuid = UUID.uuid4()
      assert {404, message} = describe_ppl_with_id(uuid, ctx)
      assert %{"message" => "Project not found"} = message
    end

    test "GET /pipelines/:ppl_id - endpoint returns 200", ctx do
      user_id = UUID.uuid4()
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, user_id)
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      assert {200, _} = describe_ppl_with_id(pipeline.id, ctx)
    end

    test "GET /pipelines/:ppl_id - pipeline execution passed", ctx do
      user_id = UUID.uuid4()
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, user_id)
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      Support.Stubs.Pipeline.change_state(pipeline.id, :passed)

      {200, %{"pipeline" => ppl}} = describe_ppl_with_id(pipeline.id, ctx)
      assert Map.get(ppl, "state") == "DONE"
      assert Map.get(ppl, "result") == "PASSED"
    end

    test "describe returns jobs", ctx do
      user_id = UUID.uuid4()
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, user_id)
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      _ =
        Support.Stubs.Pipeline.add_block(pipeline, %{
          name: "Block #1",
          dependencies: [],
          job_names: ["First job"]
        })

      {resp_code, body} = describe_ppl_with_id(pipeline.id, ctx, true, true)
      assert resp_code == 200
      assert %{"pipeline" => _ppl, "blocks" => blocks} = body

      blocks
      |> Enum.map(fn block -> assert is_list(block["jobs"]) end)
    end

    test "Unauthorized access to pipeline by non-owner should be denied", ctx do
      user_id = UUID.uuid4()
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, user_id)
      pipeline = Support.Stubs.Pipeline.create_initial(workflow)

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

      {resp_code, _body} = describe_ppl_with_id(pipeline.id, ctx, true, true)
      assert resp_code == 404
    end
  end
end
