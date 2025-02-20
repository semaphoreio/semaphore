defmodule Router.Workflows.TerminateTest do
  use PublicAPI.Case

  describe "authorized users" do
    setup do
      Support.Stubs.reset()
      project_id = UUID.uuid4()
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(org_id, user_id, "project.job.stop", project_id)

      {:ok, %{project_id: project_id, org_id: org_id, user_id: user_id}}
    end

    test "POST workflows/:wf_id/terminate - terminate workflow", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4(), organization_id: ctx.org_id)
      _ = Support.Stubs.Pipeline.create_initial(workflow, organization_id: ctx.org_id)

      assert %{"message" => "Termination started for 1 pipelines."} ==
               terminate_wf(ctx, workflow.id, 200)
    end

    test "POST workflows/:wf_id/terminate - wrong wf_id", ctx do
      assert %{"message" => "Validation Failed"} = terminate_wf(ctx, "123", 422, true)
    end

    test "POST workflows/:wf_id/terminate - workflow not owned by requester", ctx do
      hook = %{id: UUID.uuid4(), project_id: ctx.project_id, branch_id: UUID.uuid4()}
      workflow = Support.Stubs.Workflow.create(hook, UUID.uuid4(), organization_id: ctx.org_id)
      _ = Support.Stubs.Pipeline.create_initial(workflow)

      GrpcMock.stub(WorkflowMock, :describe, fn _req, _ ->
        alias InternalApi.PlumberWF.DescribeResponse

        %DescribeResponse{
          status: %InternalApi.Status{},
          workflow: %{workflow.api_model | project_id: UUID.uuid4()}
        }
      end)

      assert %{"message" => "Project not found"} = terminate_wf(ctx, workflow.id, 404, true)
    end
  end

  defp terminate_wf(ctx, wf_id, expected_status_code, decode? \\ true) do
    {:ok, response} = %{} |> Jason.encode!() |> terminate_wf_(wf_id, ctx)
    %{:body => body, :status_code => status_code} = response
    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code

    case decode? do
      true -> Jason.decode!(body)
      false -> body
    end
  end

  defp terminate_wf_(body, wf_id, ctx),
    do: HTTPoison.post(url() <> "/workflows/" <> wf_id <> "/terminate", body, headers(ctx))
end
