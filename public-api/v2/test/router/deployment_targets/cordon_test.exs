defmodule Router.Deployments.CordonTest do
  use PublicAPI.Case

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @org_without_feature UUID.uuid4()
  @default_project_id "92be1234-1234-4234-8234-123456789012"
  import Test.PipelinesClient, only: [headers: 1, url: 0]

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()

    project_id = @default_project_id
    user_id = Support.Stubs.User.default_user_id()
    Support.Stubs.Project.create(%{id: @default_org_id}, %{id: user_id}, id: project_id)

    Support.Stubs.Feature.disable_feature(@org_without_feature, "advanced_deployment_targets")

    PermissionPatrol.add_permissions(
      @default_org_id,
      user_id,
      "project.deployment_targets.manage",
      project_id
    )

    Support.Stubs.RBAC.seed_data()

    {:ok,
     extra_args: %{
       org_id: @default_org_id,
       project_id: project_id,
       requester_id: Support.Stubs.User.default_user_id(),
       user_id: Support.Stubs.User.default_user_id()
     }}
  end

  describe "PATCH /deployment_targets/:id/deactivate - cordons the deployment" do
    setup [:setup_deployment_target]

    test "when params are valid and state is on then cordons a target",
         ctx = %{target_id: target_id} do
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      target = %{target | api_model: %{target.api_model | cordoned: false}}
      Support.Stubs.DB.upsert(:deployment_targets, target)

      {status_code, _headers, _body} = patch_cordon(target_id, ctx, %{})
      assert status_code == 200

      assert %{api_model: %{cordoned: true}} =
               Support.Stubs.DB.find(:deployment_targets, target_id)
    end

    test "when target is in invalid state then returns error", ctx = %{target_id: target_id} do
      Support.Stubs.Deployments.Grpc.expect(:cordon, 1, fn ->
        raise GRPC.RPCError, status: :failed_precondition, message: "Invalid state: SYNCING"
      end)

      {status_code, _headers, message} = patch_cordon(target_id, ctx, %{})
      assert status_code == 400
      assert message == "Invalid state: SYNCING"

      GrpcMock.verify!(DeploymentsMock)
    end

    test "when params are valid but user is not authorized then returns error",
         ctx = %{target_id: target_id} do
      user_id = UUID.uuid4()

      PermissionPatrol.add_permissions(
        @default_org_id,
        user_id,
        "project.deployment_targets.view",
        ctx.extra_args.project_id
      )

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :user_id, user_id))
      {status_code, _headers, message} = patch_cordon(target_id, ctx, %{})
      assert status_code == 404
      assert message["message"] =~ "Not Found"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      org_id = UUID.uuid4()

      Support.Stubs.Feature.disable_feature(org_id, "deployment_targets")

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :org_id, org_id))

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :user_id, UUID.uuid4()))
      {status_code, _headers, message} = patch_cordon(ctx.target_id, ctx, %{})
      assert status_code == 404

      assert message["message"] ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when requester organization does not own the DT", ctx do
      Support.Stubs.Deployments.Grpc.mock_wrong_org(UUID.uuid4())

      assert {404, _headers, response} = patch_cordon(ctx.target_id, ctx, %{})
      assert %{"message" => "Not found"} = response
    end
  end

  defp setup_deployment_target(ctx) do
    project = %{org_id: ctx.extra_args.org_id, id: ctx.extra_args.project_id}
    user = %{id: ctx.extra_args.requester_id}

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

    case Jason.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  defp patch_cordon_request(_target_id, params, ctx) do
    url =
      url() <>
        "/projects/" <>
        ctx.extra_args.project_id <>
        "/deployment_targets/" <>
        ctx.target.id <> "/deactivate?" <> Plug.Conn.Query.encode(params)

    HTTPoison.patch(
      url,
      "",
      headers(ctx.extra_args)
    )
  end
end
