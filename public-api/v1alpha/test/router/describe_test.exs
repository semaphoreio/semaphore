defmodule Router.DescribeTest do
  use ExUnit.Case

  import Test.PipelinesClient,
    only: [
      url: 0,
      headers: 0,
      describe_ppl_with_id: 2,
      describe_ppl_with_id: 1,
      describe_ppl_with_id: 3
    ]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "GET /pipelines/:ppl_id - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    user_id = UUID.uuid4()

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    assert {404, message} = describe_ppl_with_id(pipeline.id, false)
    assert message == "Not Found"
  end

  test "GET /pipelines/:ppl_id - no permission" do
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
    assert {404, message} = describe_ppl_with_id(pipeline.id, false)
    assert message == "Not Found"
  end

  # Response id 404 - Not Found due to failed authorization
  test "GET /pipelines/:ppl_id - non-existing ppl_id - authorization failure" do
    uuid = UUID.uuid4()
    assert {404, message} = describe_ppl_with_id(uuid, false)
    assert message == "Not Found"

    assert {404, message} = describe_ppl_with_id("does-not-exist", false)
    assert message == "Not Found"
  end

  test "GET /pipelines/:ppl_id - endpoint returns 200" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    assert {200, _} = describe_ppl_with_id(pipeline.id)
  end

  test "GET /pipelines/:ppl_id - pipeline execution passed" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :passed)

    {200, %{"pipeline" => ppl}} = describe_ppl_with_id(pipeline.id)
    assert Map.get(ppl, "state") == "done"
    assert Map.get(ppl, "result") == "passed"
  end

  test "describe returns jobs" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    _ =
      Support.Stubs.Pipeline.add_block(pipeline, %{
        name: "Block #1",
        dependencies: [],
        job_names: ["First job"]
      })

    {resp_code, body} = describe_ppl_with_id(pipeline.id, true, true)
    assert resp_code == 200
    assert %{"pipeline" => _ppl, "blocks" => blocks} = body

    blocks
    |> Enum.map(fn block -> assert is_list(block["jobs"]) end)
  end

  test "describe validation fail - malformed request" do
    {:ok, response} = get_ppl_description_(UUID.uuid4(), "false")
    %{:body => body, :status_code => status_code} = response
    assert status_code == 404
    assert body == "Not Found"
  end

  defp get_ppl_description_(id, detailed),
    do: HTTPoison.get(url() <> "/pipelines/" <> id <> "?detailed=" <> detailed, headers())
end
