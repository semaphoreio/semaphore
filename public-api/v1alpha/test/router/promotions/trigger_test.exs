defmodule Router.Promotions.TriggerTest do
  use ExUnit.Case

  setup do
    Support.Stubs.init()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    user_id = user.id

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow, name: "Build & Test")
    switch = Support.Stubs.Pipeline.add_switch(pipeline)
    _target = Support.Stubs.Switch.add_target(switch, name: "Staging")
    Support.Stubs.Pipeline.change_state(pipeline.id, :passed)
    {:ok, %{user: user, ppl_id: pipeline.id}}
  end

  test "POST /promotions - project ID mismatch", ctx do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    project = Support.Stubs.Project.create(org, ctx.user)
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}

    workflow = Support.Stubs.Workflow.create(hook, ctx.user.id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow, name: "Build & Test")
    switch = Support.Stubs.Pipeline.add_switch(pipeline)
    _target = Support.Stubs.Switch.add_target(switch, name: "Staging")
    Support.Stubs.Pipeline.change_state(pipeline.id, :passed)

    params = %{
      "pipeline_id" => pipeline.id,
      "name" => "Staging",
      "override" => true,
      "request_token" => UUID.uuid4()
    }

    assert message = post_promotion(params, 404, false)
    assert message == "Not Found"
  end

  test "POST /promotions - no permission", ctx do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.job.rerun")
      )
    end)

    params = %{
      "pipeline_id" => ctx.ppl_id,
      "name" => "Staging",
      "override" => true,
      "request_token" => UUID.uuid4()
    }

    assert message = post_promotion(params, 404, false)
    assert message == "Not Found"
  end

  test "POST /promotions - override if provided must be boolean", ctx do
    params = %{
      "pipeline_id" => ctx.ppl_id,
      "name" => "Staging",
      "override" => "not-boolean",
      "request_token" => UUID.uuid4()
    }

    assert message = post_promotion(params, 400)
    assert message == "Invalid value of 'override' param: \"not-boolean\" - needs to be boolean."
  end

  test "POST /promotions - success when Gofer returns :OK", ctx do
    params = %{
      "pipeline_id" => ctx.ppl_id,
      "name" => "Staging",
      "override" => true,
      "request_token" => UUID.uuid4()
    }

    assert message = post_promotion(params, 200)
    assert message == "Promotion successfully triggered."
  end

  test "POST /promotions - returns REFUSED code and message when Gofer rejects trigger", ctx do
    GrpcMock.stub(GoferMock, :trigger, fn _, _ ->
      InternalApi.Gofer.TriggerResponse.new(
        response_status:
          InternalApi.Gofer.ResponseStatus.new(
            code: InternalApi.Gofer.ResponseStatus.ResponseCode.value(:REFUSED),
            message:
              "Too many pending promotions for target 'Staging' (50/50). Please retry later."
          )
      )
    end)

    params = %{
      "pipeline_id" => ctx.ppl_id,
      "name" => "Staging",
      "override" => true,
      "request_token" => UUID.uuid4()
    }

    assert response = post_promotion(params, 409)

    assert response == %{
             "code" => "REFUSED",
             "message" =>
               "Too many pending promotions for target 'Staging' (50/50). Please retry later."
           }
  end

  def post_promotion(args, expected_status_code, decode? \\ true) when is_map(args) do
    {:ok, response} = args |> Poison.encode!() |> post_promotions_request()
    %{:body => body, :status_code => status_code} = response
    if(status_code != expected_status_code, do: IO.puts("Response body: #{inspect(body)}"))
    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  def url, do: "localhost:4004"

  def headers,
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", Support.Stubs.User.default_user_id()},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]

  defp post_promotions_request(body) do
    HTTPoison.post(url() <> "/promotions", body, headers())
  end
end
