defmodule Router.WfTerminateTest do
  use ExUnit.Case

  import Test.PipelinesClient, only: [url: 0, headers: 0]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "POST workflows/:wf_id/terminate - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert "Not Found" == terminate_wf(workflow.id, 404, false)
  end

  test "POST workflows/:wf_id/terminate - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.job.stop")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert "Not Found" == terminate_wf(workflow.id, 404, false)
  end

  test "POST workflows/:wf_id/terminate - terminate workflow" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert "Termination started for 1 pipelines." == terminate_wf(workflow.id, 200)
  end

  test "POST workflows/:wf_id/terminate - wrong wf_id" do
    assert "Not Found" == terminate_wf("123", 404, false)
  end

  defp terminate_wf(wf_id, expected_status_code, decode? \\ true) do
    {:ok, response} = %{} |> Poison.encode!() |> terminate_wf_(wf_id)
    %{:body => body, :status_code => status_code} = response
    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  defp terminate_wf_(body, wf_id),
    do: HTTPoison.post(url() <> "/workflows/" <> wf_id <> "/terminate", body, headers())
end
