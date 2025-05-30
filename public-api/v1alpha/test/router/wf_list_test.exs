defmodule Router.WfListTest do
  use ExUnit.Case

  import Test.PipelinesClient, only: [url: 0, headers: 0]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "GET /workflows/ - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    params = %{project_id: project.id, branch_name: "staging", page_size: 1}
    assert {404, _headers, "Not Found"} = list_wfs(params, false)
  end

  test "GET /workflows/ - no permission" do
    GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(
        permissions: Support.Stubs.all_permissions_except("project.view")
      )
    end)

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    params = %{project_id: project.id, branch_name: "staging", page_size: 1}
    assert {404, _headers, "Not Found"} = list_wfs(params, false)
  end

  test "GET /workflows/ - endpoint returns 200" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)
    project_id = project.id

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}

    _ =
      Support.Stubs.Workflow.create(hook, UUID.uuid4(),
        branch_name: "master",
        organization_id: org.id
      )

    _ =
      Support.Stubs.Workflow.create(hook, UUID.uuid4(),
        branch_name: "staging",
        organization_id: org.id
      )

    # Older workflow is listed first
    wf3 =
      Support.Stubs.Workflow.create(hook, UUID.uuid4(),
        organization_id: org.id,
        branch_name: "staging",
        created_at: DateTime.to_unix(DateTime.utc_now()) + 100
      )

    wf3_id = wf3.id

    params = %{project_id: project_id, branch_name: "staging", page_size: 1}
    assert {200, headers, result} = list_wfs(params)

    assert [%{"wf_id" => ^wf3_id}] = result

    assert project_id |> expected_headers() |> headers_contain(headers)
  end

  def list_wfs(params, decode? \\ true) do
    {:ok, response} = get_list_wfs(params)
    %{:body => body, :status_code => status_code, headers: headers} = response

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, headers, body}
  end

  defp get_list_wfs(params) do
    url = url() <> "/workflows?" <> Plug.Conn.Query.encode(params)
    HTTPoison.get(url, headers())
  end

  defp expected_headers(project_id) do
    [
      {"link",
       "#{link(project_id, 2)}; rel=\"next\", " <>
         "#{link(project_id, 1)}; rel=\"first\", " <>
         "#{link(project_id, 2)}; rel=\"last\""},
      {"page-number", "1"},
      {"per-page", "1"},
      {"total", "2"},
      {"total-pages", "2"}
    ]
  end

  defp link(project_id, page) do
    "<http://localhost:4004/api/#{api_version()}/plumber-workflows" <>
      "?branch_name=staging&page=#{page}&page_size=1&project_id=#{project_id}>"
  end

  defp api_version(), do: System.get_env("API_VERSION")

  defp headers_contain(list, headers) do
    Enum.map(list, fn value ->
      assert Enum.find(headers, nil, fn x -> x == value end) != nil
    end)
  end
end
