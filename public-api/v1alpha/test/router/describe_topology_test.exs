defmodule Router.DescribeTopologyTest do
  use ExUnit.Case

  import Test.PipelinesClient, only: [url: 0, headers: 0]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "GET pipelines/:ppl_id/describe_topology - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    assert "Not Found" == describe_topology(pipeline.id, 404, false)
  end

  test "GET pipelines/:ppl_id/describe_topology - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.view")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    assert "Not Found" == describe_topology(pipeline.id, 404, false)
  end

  test "GET pipelines/:ppl_id/describe_topology" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    _ =
      Support.Stubs.Pipeline.add_block(pipeline, %{
        dependencies: [],
        name: "Nameless block 1",
        job_names: ["Nameless 1"]
      })

    expected = [%{"jobs" => ["Nameless 1"], "name" => "Nameless block 1", "dependencies" => []}]
    assert expected == describe_topology(pipeline.id, 200)
  end

  defp describe_topology(ppl_id, expected_status_code, decode \\ true) do
    {:ok, response} = get_ppl_description_topology(ppl_id)
    %{:body => body, :status_code => status_code} = response

    assert status_code == expected_status_code

    if decode do
      Poison.decode!(body)
    else
      body
    end
  end

  defp get_ppl_description_topology(id) do
    url = url() <> "/pipelines/#{id}/describe_topology"
    HTTPoison.get(url, headers())
  end
end
