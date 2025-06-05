defmodule Router.ListTest do
  use ExUnit.Case

  import Test.PipelinesClient, only: [url: 0, headers: 0]

  setup do
    Support.Stubs.grant_all_permissions()
    :ok
  end

  test "GET /pipelines - project ID mismatch" do
    org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert {404, _headers, "Not Found"} = list_ppls(workflow.id, false)
  end

  test "GET /pipelines - no permission" do
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
    assert {404, _headers, "Not Found"} = list_ppls(workflow.id, false)
  end

  test "GET /pipelines - endpoint returns paginated ppls (correct headers set)" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    workflow_id = workflow.id

    pipeline =
      Support.Stubs.Pipeline.create_initial(workflow,
        name: "Pipeline #1",
        commit_sha: "75891a4469488cb714b6931bfd63ecb71180f7ad",
        branch_name: "master",
        working_directory: ".semaphore",
        yaml_file_name: "semaphore.yml"
      )

    hook_id = hook.id
    pipeline_id = pipeline.id
    project_id = project.id
    assert {200, headers, list_res} = list_ppls_from(project_id, "master")

    assert [
             %{
               "branch_name" => "master",
               "commit_sha" => "75891a4469488cb714b6931bfd63ecb71180f7ad",
               "created_at" => %{"nanos" => _, "seconds" => _},
               "done_at" => %{"nanos" => _, "seconds" => _},
               "pending_at" => %{"nanos" => _, "seconds" => _},
               "queuing_at" => %{"nanos" => _, "seconds" => _},
               "running_at" => %{"nanos" => _, "seconds" => _},
               "stopping_at" => %{"nanos" => _, "seconds" => _},
               "error_description" => "",
               "name" => "Pipeline #1",
               "state" => "QUEUING",
               "switch_id" => "",
               "terminate_request" => "",
               "terminated_by" => "",
               "working_directory" => ".semaphore",
               "yaml_file_name" => "semaphore.yml",
               "branch_id" => _,
               "hook_id" => ^hook_id,
               "ppl_id" => ^pipeline_id,
               "project_id" => ^project_id,
               "wf_id" => ^workflow_id
             }
           ] = list_res

    assert project_id |> expected_headers() |> headers_contain(headers)
  end

  test "GET /pipelines - params: wf_id and no project_id" do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    user_id = user.id
    project = Support.Stubs.Project.create(org, user)

    hook = %{id: UUID.uuid4(), project_id: project.id, branch_id: UUID.uuid4()}
    workflow = Support.Stubs.Workflow.create(hook, user_id, organization_id: org.id)
    _ = Support.Stubs.Pipeline.create_initial(workflow)
    assert {200, _headers, _list_res} = list_ppls(workflow.id)
  end

  test "GET /pipelines - no wf_id with and no project_id" do
    {:ok, response} = HTTPoison.get(url() <> "/pipelines?", headers())
    %{body: "Not Found", status_code: 404, headers: _} = response
  end

  defp list_ppls(wf_id, decode? \\ true) do
    params = %{wf_id: wf_id}
    {:ok, response} = get_list_ppls(params)
    %{body: body, status_code: status_code, headers: headers} = response

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, headers, body}
  end

  defp list_ppls_from(project_id, branch_name) do
    params = %{project_id: project_id, branch_name: branch_name}
    {:ok, response} = get_list_ppls(params)
    %{body: body, status_code: status_code, headers: headers} = response
    {status_code, headers, Poison.decode!(body)}
  end

  defp headers_contain(list, headers) do
    Enum.map(list, fn value ->
      assert Enum.find(headers, nil, fn x -> x == value end) != nil
    end)
  end

  defp expected_headers(project_id) do
    [
      {"link", "#{link(project_id)}; rel=\"first\", #{link(project_id)}; rel=\"last\""},
      {"page-number", "1"},
      {"per-page", "30"},
      {"total", "1"},
      {"total-pages", "1"}
    ]
  end

  defp link(project_id) do
    "<http://localhost:4004/api/#{api_version()}/pipelines" <>
      "?branch_name=master&page=1&project_id=#{project_id}>"
  end

  defp api_version(), do: System.get_env("API_VERSION")

  defp get_list_ppls(params) do
    url = url() <> "/pipelines?" <> Plug.Conn.Query.encode(params)
    HTTPoison.get(url, headers())
  end
end
