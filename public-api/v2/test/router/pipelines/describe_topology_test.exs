defmodule Router.DescribeTopologyTest do
  use PublicAPI.Case

  describe "authorized users" do
    setup do
      Support.Stubs.init()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

      PermissionPatrol.add_permissions(org_id, user_id, "project.view", project_id)

      {:ok, %{project_id: project_id, org_id: org_id, user_id: user_id}}
    end

    test "GET pipelines/:ppl_id/describe_topology", ctx do
      user_id = ctx.user_id
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, user_id)
      pipeline = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      _ =
        Support.Stubs.Pipeline.add_block(pipeline, %{
          dependencies: [],
          name: "Nameless block 1",
          job_names: ["Nameless 1"]
        })

      assert %{
               "blocks" => [
                 %{"jobs" => ["Nameless 1"], "name" => "Nameless block 1", "dependencies" => []}
               ],
               "after_pipeline" => _
             } = describe_topology(ctx, pipeline.id, 200)
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

      assert %{"message" => "Not Found"} = describe_topology(ctx, pipeline.id, 404)
    end
  end

  defp describe_topology(ctx, ppl_id, expected_status_code) do
    {:ok, response} = get_ppl_description_topology(ctx, ppl_id)
    %{:body => body, :status_code => status_code} = response

    assert status_code == expected_status_code
    Jason.decode!(body)
  end

  defp get_ppl_description_topology(ctx, id) do
    url = url() <> "/pipelines/#{id}/describe_topology"
    HTTPoison.get(url, headers(ctx), timeout: 100_000, recv_timeout: 100_000)
  end
end
