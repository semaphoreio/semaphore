defmodule Router.TerminateTest do
  use ExUnit.Case

  import Test.PipelinesClient,
    only: [
      url: 0,
      headers: 0,
      describe_ppl_with_id: 1,
      describe_ppl_with_id: 3,
      describe_ppl_with_id: 4
    ]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "PATCH /pipelines/:ppl_id - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    Support.Stubs.Pipeline.add_blocks(pipeline, [
      %{name: "Block #1", dependencies: [], job_names: ["First job"]},
      %{name: "Block #2", dependencies: [], job_names: ["Second job"]}
    ])

    Support.Stubs.Pipeline.change_state(pipeline.id, :running)

    headers = [
      {"Content-Type", "application/json"},
      {"x-semaphore-org-id", org.id},
      {"x-semaphore-user-id", user_id}
    ]

    assert_state(pipeline.id, "running", headers)

    assert "Not Found" == terminate_ppl(pipeline.id, %{terminate_request: true}, 404, false)
  end

  test "PATCH /pipelines/:ppl_id - no permission" do
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
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    Support.Stubs.Pipeline.add_blocks(pipeline, [
      %{name: "Block #1", dependencies: [], job_names: ["First job"]},
      %{name: "Block #2", dependencies: [], job_names: ["Second job"]}
    ])

    Support.Stubs.Pipeline.change_state(pipeline.id, :running)
    assert_state(pipeline.id, "running")

    assert "Not Found" == terminate_ppl(pipeline.id, %{terminate_request: true}, 404, false)
  end

  test "PATCH /pipelines/:ppl_id - terminate running pipeline" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)

    Support.Stubs.Pipeline.add_blocks(pipeline, [
      %{name: "Block #1", dependencies: [], job_names: ["First job"]},
      %{name: "Block #2", dependencies: [], job_names: ["Second job"]}
    ])

    Support.Stubs.Pipeline.change_state(pipeline.id, :running)
    assert_state(pipeline.id, "running")

    assert "Pipeline termination started." ==
             terminate_ppl(pipeline.id, %{terminate_request: true}, 200)

    assert_state(pipeline.id, "done")
    {200, %{"pipeline" => ppl}} = describe_ppl_with_id(pipeline.id)
    assert "stopped" = Map.get(ppl, "result")

    assert_blocks_results(pipeline.id)
  end

  # Response is 404 - Not Found due to failed authorization
  test "PATCH /pipelines/:ppl_id - terminate fail - wrong id" do
    uuid = UUID.uuid4()
    args = %{terminate_request: true}

    assert "Not Found" ==
             terminate_ppl(uuid, args, 404, false)

    assert "Not Found" ==
             terminate_ppl("not-found", args, 404, false)
  end

  test "PATCH /pipelines/:ppl_id - terminate fail - missing param" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :running)
    assert_state(pipeline.id, "running")

    args = %{something: true}

    assert "Value of 'terminate_request' field must be boolean value 'true'." ==
             terminate_ppl(pipeline.id, args, 400)
  end

  test "PATCH /pipelines/:ppl_id - terminate fail - wrong param value" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow)
    Support.Stubs.Pipeline.change_state(pipeline.id, :running)
    assert_state(pipeline.id, "running")

    args = %{terminate_request: false}

    assert "Value of 'terminate_request' field must be boolean value 'true'." ==
             terminate_ppl(pipeline.id, args, 400)
  end

  defp assert_state(ppl_id, state, headers \\ nil) do
    assert {200, body} =
             if(headers,
               do: describe_ppl_with_id(ppl_id, true, false, headers),
               else: describe_ppl_with_id(ppl_id, true, false)
             )

    %{"pipeline" => ppl} = body
    assert state == Map.get(ppl, "state")
  end

  defp terminate_ppl(ppl_id, args, expected_status_code, decode? \\ true) do
    {:ok, response} = args |> Poison.encode!() |> terminate_ppl_with_id(ppl_id)
    %{:body => body, :status_code => status_code} = response
    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  defp assert_blocks_results(ppl_id) do
    assert {200, %{"blocks" => blocks}} = describe_ppl_with_id(ppl_id, true, true)
    assert is_list(blocks)

    block_one = Enum.at(blocks, 0)
    assert Map.get(block_one, "state") == "done"
    assert Map.get(block_one, "result") == "stopped"

    block_two = Enum.at(blocks, 1)
    assert Map.get(block_one, "state") == "done"
    assert Map.get(block_two, "result") == "stopped"
  end

  defp terminate_ppl_with_id(body, id),
    do: HTTPoison.patch(url() <> "/pipelines/" <> id, body, headers())
end
