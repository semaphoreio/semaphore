defmodule Router.RescheduleTest do
  use ExUnit.Case

  import Test.PipelinesClient, only: [post_reschedule: 3, post_reschedule: 4]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "POST /workflows/:wf_id/reschedule - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    response = post_reschedule(workflow.id, %{"request_token" => UUID.uuid4()}, 404, false)
    assert response == "Not Found"
  end

  test "POST /workflows/:wf_id/reschedule - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.job.rerun")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    response = post_reschedule(workflow.id, %{"request_token" => UUID.uuid4()}, 404, false)
    assert response == "Not Found"
  end

  test "POST /workflows/:wf_id/reschedule - valid args" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    response = post_reschedule(workflow.id, %{"request_token" => UUID.uuid4()}, 200)
    assert %{"wf_id" => wf_id, "ppl_id" => ppl_id} = response
    assert {:ok, _} = UUID.info(ppl_id)
    assert {:ok, _} = UUID.info(wf_id)
  end

  test "POST /workflows/:wf_id/reschedule - wrong wf_id" do
    response = post_reschedule("123", %{"request_token" => UUID.uuid4()}, 404, false)
    assert response == "Not Found"
  end

  test "POST /workflows/:wf_id/reschedule - request token missing" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)

    response = post_reschedule(workflow.id, %{"request_token" => ""}, 400)
    assert response == "Missing required post parameter request_token."
  end
end
