defmodule Router.TerminateTest do
  use PublicAPI.Case

  import Test.PipelinesClient,
    only: [url: 0, headers: 1, describe_ppl_with_id: 2, describe_ppl_with_id: 4]

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.job.stop", project.id)
      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project.id)

      {:ok, %{project_id: project.id, org_id: org_id, user_id: user_id}}
    end

    test "POST /pipelines/:ppl_id - terminate running pipeline", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      Support.Stubs.Pipeline.add_blocks(pipeline, [
        %{name: "Block #1", dependencies: [], job_names: ["First job"]},
        %{name: "Block #2", dependencies: [], job_names: ["Second job"]}
      ])

      Support.Stubs.Pipeline.change_state(pipeline.id, :running)
      assert_state(pipeline.id, ctx, "RUNNING")

      assert %{"message" => "Pipeline termination started."} ==
               terminate_ppl(ctx, pipeline.id, %{terminate_request: true}, 200)

      assert_state(pipeline.id, ctx, "DONE")
      {200, %{"pipeline" => ppl}} = describe_ppl_with_id(pipeline.id, ctx)
      assert "STOPPED" = Map.get(ppl, "result")

      assert_blocks_results(pipeline.id, ctx)
    end

    # Response is 404 - Not Found due to failed authorization
    test "POST /pipelines/:ppl_id - terminate fail - wrong id", ctx do
      uuid = UUID.uuid4()
      args = %{terminate_request: true}

      assert %{"message" => "Project not found"} = terminate_ppl(ctx, uuid, args, 404)

      assert %{"message" => "Validation Failed"} = terminate_ppl(ctx, "not-found", args, 422)
    end

    test "POST /pipelines/:ppl_id - terminate fail - missing param", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      Support.Stubs.Pipeline.change_state(pipeline.id, :running)
      assert_state(pipeline.id, ctx, "RUNNING")

      args = %{something: true}

      assert %{"message" => "Validation Failed"} = terminate_ppl(ctx, pipeline.id, args, 422)
    end

    test "POST /pipelines/:ppl_id - terminate fail - wrong param value", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4())
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)
      Support.Stubs.Pipeline.change_state(pipeline.id, :running)
      assert_state(pipeline.id, ctx, "RUNNING")

      args = %{terminate_request: false}

      assert %{
               "message" => "Value of 'terminate_request' field must be explicitly set to 'true'."
             } = terminate_ppl(ctx, pipeline.id, args, 400)
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

      args = %{terminate_request: false}

      assert %{"message" => "Not Found"} = terminate_ppl(ctx, pipeline.id, args, 404)
    end
  end

  defp assert_state(ppl_id, ctx, state) do
    assert {200, body} = describe_ppl_with_id(ppl_id, ctx)
    %{"pipeline" => ppl} = body
    assert state == Map.get(ppl, "state")
  end

  defp terminate_ppl(ctx, ppl_id, args, expected_status_code, decode? \\ true) do
    {:ok, response} = args |> Jason.encode!() |> terminate_ppl_with_id(ppl_id, ctx)
    %{:body => body, :status_code => status_code} = response
    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code

    case decode? do
      true -> Jason.decode!(body)
      false -> body
    end
  end

  defp assert_blocks_results(ppl_id, ctx) do
    assert {200, %{"blocks" => blocks}} = describe_ppl_with_id(ppl_id, ctx, true, true)
    assert is_list(blocks)

    block_one = Enum.at(blocks, 0)
    assert Map.get(block_one, "state") == "DONE"
    assert Map.get(block_one, "result") == "STOPPED"

    block_two = Enum.at(blocks, 1)
    assert Map.get(block_one, "state") == "DONE"
    assert Map.get(block_two, "result") == "STOPPED"
  end

  defp terminate_ppl_with_id(body, id, ctx),
    do: HTTPoison.post(url() <> "/pipelines/" <> id <> "/terminate", body, headers(ctx))
end
