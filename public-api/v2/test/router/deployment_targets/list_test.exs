defmodule Router.Deployments.ListTest do
  use PublicAPI.Case

  import Test.PipelinesClient, only: [headers: 1, url: 0]

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    project_id = UUID.uuid4()
    org_id = UUID.uuid4()
    user_id = UUID.uuid4()
    project = Support.Stubs.Project.create(%{id: org_id}, %{id: user_id}, id: project_id)

    PermissionPatrol.add_permissions(
      org_id,
      user_id,
      "project.deployment_targets.view",
      project_id
    )

    {:ok,
     %{
       org_id: org_id,
       project_id: project_id,
       project_name: project.name,
       user_id: user_id
     }}
  end

  describe "GET /deployment_targets/ (only project_id) - endpoint returns list of deployments" do
    setup [:setup_three_targets]

    test "request list of deployment targets and get :ok response", ctx do
      assert {200, _headers, targets} = list_deployments(ctx, ctx.project_id)
      assert length(targets) == 3
    end

    test "when using project name get :ok response", ctx do
      project_name = ctx.project_name
      assert {200, _headers, targets} = list_deployments(ctx, project_name)
      assert length(targets) == 3
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      ctx = Map.put(ctx, :user_id, UUID.uuid4())
      {status_code, _headers, resp} = list_deployments(ctx, ctx.project_id)
      assert status_code == 404
      assert resp["message"] == "Not Found"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      org_id = UUID.uuid4()
      user_id = UUID.uuid4()
      Support.Stubs.Feature.disable_feature(org_id, "deployment_targets")
      PermissionPatrol.add_permissions(org_id, user_id, "organization.deployment_targets.view")

      ctx = Map.put(ctx, :org_id, org_id)
      ctx = Map.put(ctx, :user_id, user_id)
      {status_code, _headers, resp} = list_deployments(ctx, ctx.project_id)
      assert status_code == 404

      assert resp["message"] =~ "Feature is not enabled"
    end

    test "when response contains dt that is not owned by requester org then returns 404", ctx do
      wrong_org = UUID.uuid4()

      GrpcMock.stub(DeploymentsMock, :list, fn req, _opts ->
        alias Support.Stubs.DB

        targets =
          :deployment_targets
          |> DB.find_all_by(:project_id, req.project_id)
          |> Enum.map(& &1.api_model)
          |> Enum.map(fn dt -> %{dt | organization_id: wrong_org} end)

        %InternalApi.Gofer.DeploymentTargets.ListResponse{targets: targets}
      end)

      assert {404, _headers, response} = list_deployments(ctx, ctx.project_id)
      assert %{"message" => "Not found"} = response
    end
  end

  defp setup_three_targets(ctx) do
    project = %{org_id: ctx.org_id, id: ctx.project_id}
    user = %{id: ctx.user_id}

    for i <- 1..3, do: Support.Stubs.Deployments.create(project, user, "target#{i}")
    :ok
  end

  defp list_deployments(ctx, project_id_or_name, params \\ %{}) do
    {:ok, response} = get_list_request(ctx, project_id_or_name, params)
    %{body: body, status_code: status_code, headers: headers} = response

    case Jason.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  def headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  defp get_list_request(ctx, project, params) do
    url =
      url() <>
        "/projects/#{project}/deployment_targets?" <>
        Plug.Conn.Query.encode(params)

    HTTPoison.get(url, headers(ctx))
  end
end
