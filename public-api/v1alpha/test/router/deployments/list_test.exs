defmodule Router.Deployments.ListTest do
  use ExUnit.Case

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user)

    Support.Stubs.Feature.enable_feature(org.id, :deployment_targets)

    {:ok,
     extra_args: %{
       "organization_id" => org.id,
       "project_id" => project.id,
       "requester_id" => user.id
     }}
  end

  describe "GET /deployment_targets/ (only project_id) - endpoint returns list of deployments" do
    setup [:setup_three_targets]

    test "request list of deployment targets from project outside org and gets 404", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      user = Support.Stubs.User.create_default()
      project = Support.Stubs.Project.create(org, user)

      assert {404, _headers, "Not found"} =
               list_deployments(%{
                 ctx
                 | extra_args: Map.put(ctx.extra_args, "project_id", project.id)
               })
    end

    test "request list of deployment targets and get :ok response", ctx do
      assert {200, _headers, targets} = list_deployments(ctx)
      assert length(targets) == 3
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.deployment_targets.view")
        )
      end)

      {status_code, _headers, message} = list_deployments(ctx)
      assert status_code == 401
      assert message == "Permission denied"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      {status_code, _headers, message} = list_deployments(ctx)
      assert status_code == 403

      assert message ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end
  end

  describe "GET /deployment_targets/ (project_id and target_name) - endpoint returns list of deployments" do
    setup [:setup_three_targets]

    test "when params are valid and target exists by name it describes a target", ctx do
      target_name = "target1"

      params = %{
        "target_name" => target_name,
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, targets} = list_deployments(ctx, params)
      assert status_code == 200
      assert length(targets) == 1
      assert [%{"name" => ^target_name, "active" => true}] = targets
    end

    test "when params are valid and target doesn't exist by name it returns an error", ctx do
      targetName = "fakeName"

      params = %{
        "target_name" => targetName,
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, targets} = list_deployments(ctx, params)
      assert status_code == 200
      assert length(targets) == 0
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.deployment_targets.view")
        )
      end)

      targetName = "fakeName"

      params = %{
        "target_name" => targetName,
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = list_deployments(ctx, params)
      assert status_code == 401
      assert message == "Permission denied"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      target_name = "target1"

      params = %{
        "target_name" => target_name,
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = list_deployments(ctx, params)
      assert status_code == 403

      assert message ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end
  end

  defp setup_three_targets(ctx) do
    project = %{org_id: ctx.extra_args["organization_id"], id: ctx.extra_args["project_id"]}
    user = %{id: ctx.extra_args["requester_id"]}

    for i <- 1..3, do: Support.Stubs.Deployments.create(project, user, "target#{i}")
    {:ok, project_id: project.id}
  end

  defp list_deployments(ctx, params \\ %{}) do
    {:ok, response} = get_list_request(ctx, params)
    %{body: body, status_code: status_code, headers: headers} = response

    case Poison.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  def url, do: "localhost:4004"

  def headers(user_id, org_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", org_id}
    ]

  defp get_list_request(ctx, params) do
    url =
      case Map.has_key?(params, "target_name") do
        true ->
          url() <>
            "/deployment_targets?" <>
            Plug.Conn.Query.encode(%{
              project_id: ctx.extra_args["project_id"],
              target_name: params["target_name"]
            })

        false ->
          url() <>
            "/deployment_targets?" <>
            Plug.Conn.Query.encode(%{project_id: ctx.extra_args["project_id"]})
      end

    HTTPoison.get(url, headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"]))
  end
end
