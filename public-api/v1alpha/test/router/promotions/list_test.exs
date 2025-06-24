defmodule Router.Promotions.ListTest do
  use ExUnit.Case

  setup do
    Support.Stubs.init()
    Support.Stubs.grant_all_permissions()

    user = Support.Stubs.User.create_default()
    org = Support.Stubs.Organization.create_default()
    project = Support.Stubs.Project.create(org, user)
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}

    workflow = Support.Stubs.Workflow.create(hook, user.id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow, name: "Build & Test")
    switch = Support.Stubs.Pipeline.add_switch(pipeline)
    _ = Support.Stubs.Switch.add_target(switch, name: "Staging")
    Support.Stubs.Pipeline.change_state(pipeline.id, :passed)
    {:ok, %{user: user, org: org, project: project, ppl_id: pipeline.id}}
  end

  test "GET /promotions - project ID mismatch", ctx do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    project = Support.Stubs.Project.create(org, ctx.user)
    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}

    workflow = Support.Stubs.Workflow.create(hook, ctx.user.id, organization_id: org.id)
    pipeline = Support.Stubs.Pipeline.create_initial(workflow, name: "Build & Test")
    switch = Support.Stubs.Pipeline.add_switch(pipeline)
    _ = Support.Stubs.Switch.add_target(switch, name: "Staging")
    Support.Stubs.Pipeline.change_state(pipeline.id, :passed)

    1..3 |> Enum.map(fn _ -> promote_pipeline(pipeline.id, headers(org, ctx.user)) end)
    :timer.sleep(1_000)
    assert {404, _headers, _list_res} = list_promotions(pipeline.id, "", false)
  end

  test "GET /promotions/ (only ppl_id) - no permission", ctx do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.view")
      )
    end)

    1..3 |> Enum.map(fn _ -> promote_pipeline(ctx.ppl_id) end)
    :timer.sleep(1_000)
    assert {404, _headers, _list_res} = list_promotions(ctx.ppl_id, "", false)
  end

  test "GET /promotions/ (only ppl_id) - endpoint returns paginated promotions", ctx do
    1..3 |> Enum.map(fn _ -> promote_pipeline(ctx.ppl_id) end)

    :timer.sleep(1_000)

    assert {200, headers, list_res} = list_promotions(ctx.ppl_id)
    assert is_list(list_res) and length(list_res) == 3

    assert ctx.ppl_id |> expected_headers() |> headers_contain(headers)
  end

  test "GET /promotions/ (all params) - endpoint returns paginated promotions", ctx do
    1..3 |> Enum.map(fn _ -> promote_pipeline(ctx.ppl_id) end)

    :timer.sleep(1_000)

    assert {200, headers, list_res} = list_promotions(ctx.ppl_id, "Foo promotion")
    assert is_list(list_res) and length(list_res) == 3

    assert ctx.ppl_id |> expected_headers("Foo promotion") |> headers_contain(headers)
  end

  defp list_promotions(ppl_id, target_name \\ "", decode \\ true) do
    params = %{pipeline_id: ppl_id, name: target_name}
    {:ok, response} = get_promotions_request(params, headers())
    %{body: body, status_code: status_code, headers: headers} = response

    if decode do
      {status_code, headers, Poison.decode!(body)}
    else
      {status_code, headers, body}
    end
  end

  defp promote_pipeline(ppl_id, headers \\ headers()) do
    params = %{
      "pipeline_id" => ppl_id,
      "name" => "Staging",
      "override" => true,
      "request_token" => UUID.uuid4()
    }

    assert message = post_promotion(params, headers, 200)
    assert message == "Promotion successfully triggered."
  end

  def post_promotion(args, headers, expected_status_code, decode? \\ true) when is_map(args) do
    {:ok, response} = args |> Poison.encode!() |> post_promotions_request(headers)
    %{:body => body, :status_code => status_code} = response
    assert status_code == expected_status_code

    case decode? do
      true -> Poison.decode!(body)
      false -> body
    end
  end

  defp headers_contain(list, headers) do
    Enum.map(list, fn value ->
      assert Enum.find(headers, nil, fn x -> x == value end) != nil
    end)
  end

  defp expected_headers(ppl_id, name \\ "") do
    [
      {"link", "#{link(ppl_id, name)}; rel=\"first\", #{link(ppl_id, name)}; rel=\"last\""},
      {"page-number", "1"},
      {"per-page", "10"},
      {"total", "3"},
      {"total-pages", "1"}
    ]
  end

  defp link(ppl_id, name) do
    name = name |> String.replace(" ", "+")

    "<http://localhost:4004/api/#{api_version()}/promotions" <>
      "?name=#{name}&page=1&pipeline_id=#{ppl_id}>"
  end

  def url, do: "localhost:4004"

  defp api_version(), do: System.get_env("API_VERSION")

  def headers,
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", Support.Stubs.User.default_user_id()},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]

  def headers(org, user),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user.id},
      {"x-semaphore-org-id", org.id}
    ]

  defp post_promotions_request(body, headers) do
    HTTPoison.post(url() <> "/promotions", body, headers)
  end

  defp get_promotions_request(params, headers) do
    url = url() <> "/promotions?" <> Plug.Conn.Query.encode(params)
    HTTPoison.get(url, headers)
  end
end
