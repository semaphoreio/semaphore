defmodule Router.Deployments.CordonTest do
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

  describe "PATCH /deployment_targets/:id/deactivate - cordons the deployment" do
    setup [:setup_deployment_target]

    test "when project ID doesn't match then returns error", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      user = Support.Stubs.User.create_default()
      project = Support.Stubs.Project.create(org, user)

      Support.Stubs.Feature.enable_feature(org.id, :deployment_targets)

      {target, _secret} = Support.Stubs.Deployments.create(project, user, "target")

      {status_code, _headers, _body} =
        patch_cordon(target.id, ctx, %{"project_id" => ctx.extra_args["project_id"]})

      assert status_code == 404
    end

    test "when params are valid and state is on then cordons a target",
         ctx = %{target_id: target_id} do
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      target = %{target | api_model: %{target.api_model | cordoned: false}}
      Support.Stubs.DB.upsert(:deployment_targets, target)

      params = %{
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, _body} = patch_cordon(target_id, ctx, params)
      assert status_code == 200

      assert %{api_model: %{cordoned: true}} =
               Support.Stubs.DB.find(:deployment_targets, target_id)
    end

    test "when params are valid and project_id is missing and state is on then cordons a target",
         ctx = %{target_id: target_id} do
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      target = %{target | api_model: %{target.api_model | cordoned: false}}
      Support.Stubs.DB.upsert(:deployment_targets, target)

      params = %{}

      {status_code, _headers, _body} = patch_cordon(target_id, ctx, params)
      assert status_code == 200

      assert %{api_model: %{cordoned: true}} =
               Support.Stubs.DB.find(:deployment_targets, target_id)
    end

    test "when target doesn't exist then returns error", ctx do
      target_id = "00000000-0000-4000-8000-000000000000"

      params = %{
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = patch_cordon(target_id, ctx, params)
      assert status_code == 404
      assert message == "Target not found"
    end

    test "when target is in invalid state then returns error", ctx = %{target_id: target_id} do
      Support.Stubs.Deployments.Grpc.expect(:cordon, 2, fn ->
        raise GRPC.RPCError, status: :failed_precondition, message: "Invalid state: SYNCING"
      end)

      params = %{
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = patch_cordon(target_id, ctx, params)
      assert status_code == 400
      assert message == "Invalid state: SYNCING"

      params = %{
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = patch_cordon(target_id, ctx, params)
      assert status_code == 400
      assert message == "Invalid state: SYNCING"

      GrpcMock.verify!(DeploymentsMock)
    end

    test "when params are valid but user is not authorized then returns error",
         ctx = %{target_id: target_id} do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.deployment_targets.manage")
        )
      end)

      params = %{
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = patch_cordon(target_id, ctx, params)
      assert status_code == 401
      assert message == "Permission denied"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))

      params = %{
        "project_id" => ctx.extra_args["project_id"]
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      {status_code, _headers, message} = patch_cordon(ctx.target_id, ctx, params)
      assert status_code == 403

      assert message ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when target id is not valid UUID it returns error", ctx do
      target_id = "fakeId"

      params = %{
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = patch_cordon(target_id, ctx, params)
      assert status_code == 400
      assert message == "target_id must be a valid UUID"
    end
  end

  defp setup_deployment_target(ctx) do
    project = %{org_id: ctx.extra_args["organization_id"], id: ctx.extra_args["project_id"]}
    user = %{id: ctx.extra_args["requester_id"]}

    {target, secret} =
      Support.Stubs.Time.travel_back(60, fn ->
        Support.Stubs.Deployments.create(project, user, "target",
          env_vars: [%{name: "VAR", value: "VALUE"}],
          files: [%{path: "FILE", content: "CONTENT"}]
        )
      end)

    {:ok, %{target_id: target.id, target: target, secret_id: secret.id, secret: secret}}
  end

  defp patch_cordon(target_id, ctx, params) do
    res = patch_cordon_request(target_id, params, ctx)
    {:ok, response} = res
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

  defp patch_cordon_request(target_id, params, ctx) do
    url =
      url() <>
        "/deployment_targets/" <> target_id <> "/deactivate?" <> Plug.Conn.Query.encode(params)

    HTTPoison.patch(
      url,
      "",
      headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"])
    )
  end
end
