defmodule Router.PartialRebuildTest do
  use ExUnit.Case

  import Test.PipelinesClient,
    only: [
      post_partial_rebuild: 3,
      post_partial_rebuild: 4,
      describe_ppl_with_id: 1
    ]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "POST /pipelines/:pipeline_id/partial_rebuild - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :failed)

    assert "Not Found" =
             post_partial_rebuild(pipeline.id, %{"request_token" => UUID.uuid4()}, 404, false)
  end

  test "POST /pipelines/:pipeline_id/partial_rebuild - 403 when user does not have permission" do
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
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :failed)

    assert "Not Found" =
             post_partial_rebuild(pipeline.id, %{"request_token" => UUID.uuid4()}, 404, false)
  end

  test "POST /pipelines/:pipeline_id/partial_rebuild - valid args" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :failed)

    assert %{"pipeline_id" => ppl_id} =
             post_partial_rebuild(pipeline.id, %{"request_token" => UUID.uuid4()}, 200)

    assert {:ok, _} = UUID.info(ppl_id)
  end

  test "POST /pipelines/:pipeline_id/partial_rebuild - pipeline in state done and result passed" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :passed)

    resp = post_partial_rebuild(pipeline.id, %{"request_token" => UUID.uuid4()}, 400)
    assert resp == "Pipelines which passed can not be partial rebuilt."
  end

  test "POST /pipelines/:pipeline_id/partial_rebuild - not in state done" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :running)

    assert {200, response} = describe_ppl_with_id(pipeline.id)
    assert %{"pipeline" => %{"state" => state}} = response
    assert state != "done"

    resp = post_partial_rebuild(pipeline.id, %{"request_token" => UUID.uuid4()}, 400)
    assert resp == "Only pipelines which are in done state can be partial rebuilt."
  end

  test "POST /pipelines/:pipeline_id/partial_rebuild -request token empty" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :failed)

    assert {200, _response} = describe_ppl_with_id(pipeline.id)

    resp = post_partial_rebuild(pipeline.id, %{"request_token" => ""}, 400)
    assert resp == "Missing required post parameter request_token."
  end
end
