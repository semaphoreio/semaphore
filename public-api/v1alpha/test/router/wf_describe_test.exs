defmodule Router.WfDescribeTest do
  use ExUnit.Case

  import Test.PipelinesClient, only: [describe_wf: 2, describe_wf: 1]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "GET /workflows/:wf_id - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert {404, _} = describe_wf(workflow.id, false)
  end

  test "GET /workflows/:wf_id - no permission" do
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
    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert {404, _} = describe_wf(workflow.id, false)
  end

  test "GET /workflows/:wf_id - endpoint returns 200" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert {200, _} = describe_wf(workflow.id)
  end

  test "GET /workflows/:wf_id - endpoint returns 200 for workflow triggered by MANUAL_RUN" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)

    workflow =
      Support.Stubs.Workflow.create(hook, user_id,
        organization_id: org.id,
        triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:MANUAL_RUN)
      )

    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert {200, %{"workflow" => %{"triggered_by" => "MANUAL_RUN"}}} = describe_wf(workflow.id)
  end

  test "GET /workflows/:wf_id - non-existing wf_id - authorization failure" do
    uuid = UUID.uuid4()
    assert {404, message} = describe_wf(uuid, false)
    assert message == "Not Found"

    assert {404, message} = describe_wf("does-not-exist", false)
    assert message == "Not Found"
  end
end
