defmodule Router.Deployments.DeleteTest do
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

  describe "DELETE /deployment_targets/ - endpoint to delete deployment target" do
    test "when params are valid then deletes the target", ctx do
      {target, _} = setup_deployment(ctx)

      params = %{
        "unique_token" => UUID.uuid4()
      }

      target_id = target.id

      assert {status_code, _headers, %{"id" => target_deleted_id}} =
               delete_deployment(target_id, ctx, params)

      assert status_code == 200
      assert target.id == target_deleted_id
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target == nil
    end

    test "when unique token is missing it doesn't delete the target", ctx do
      target_id = UUID.uuid4()

      params = %{}

      Support.Stubs.DB.insert(:deployment_targets, %{
        id: target_id,
        project_id: ctx.extra_args.project_id,
        name: "TargetName",
        unique_token: UUID.uuid4(),
        api_model:
          Util.Proto.deep_new!(InternalApi.Gofer.DeploymentTargets.DeploymentTarget, params),
        history: []
      })

      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target != nil
      assert target.id == target_id

      assert {status_code, _headers, message} = delete_deployment(target_id, ctx, params)

      assert status_code == 422
      assert message["message"] == "Validation Failed"

      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target != nil
      assert target.id == target_id
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      target_id = UUID.uuid4()

      params = %{
        unique_token: UUID.uuid4()
      }

      Support.Stubs.DB.insert(:deployment_targets, %{
        id: target_id,
        project_id: ctx.extra_args.project_id,
        name: "TargetName",
        unique_token: params.unique_token,
        api_model:
          Util.Proto.deep_new!(InternalApi.Gofer.DeploymentTargets.DeploymentTarget, params),
        history: []
      })

      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target != nil
      assert target.id == target_id
      user_id = UUID.uuid4()
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :user_id, user_id))

      {status_code, _headers, message} = delete_deployment(target_id, ctx, params)
      assert status_code == 404
      assert message["message"] =~ "Not Found"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      target_id = UUID.uuid4()
      org_id = UUID.uuid4()
      Support.Stubs.Feature.disable_feature(org_id, "deployment_targets")
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :org_id, org_id))

      params = %{
        "unique_token" => UUID.uuid4()
      }

      {status_code, _headers, message} = delete_deployment(target_id, ctx, params)
      assert status_code == 404

      assert message["message"] =~ "Feature is not enabled"
    end

    test "when DT does not exits => returns error", ctx do
      target_id = UUID.uuid4()

      params = %{
        "unique_token" => UUID.uuid4()
      }

      {status_code, _headers, message} = delete_deployment(target_id, ctx, params)
      assert status_code == 404
      assert message["message"] == "Not found"
    end

    test "when DT not owned by requester org", ctx do
      {target, _} = setup_deployment(ctx)

      params = %{
        "unique_token" => UUID.uuid4()
      }

      target_id = target.id

      Support.Stubs.Deployments.Grpc.mock_wrong_org(UUID.uuid4())

      assert {404, _headers, response} = delete_deployment(target_id, ctx, params)

      assert %{"message" => "Not found"} = response
    end
  end

  defp setup_deployment(ctx) do
    project = %{org_id: ctx.extra_args.org_id, id: ctx.extra_args.project_id}
    user = %{id: ctx.extra_args.requester_id}

    Support.Stubs.Deployments.create(project, user, "target", %{
      env_vars: [%{name: "X", value: "123"}],
      files: [%{path: "/lib/code.ex", content: "abc"}]
    })
  end

  defp delete_deployment(target_id, ctx, params) do
    {:ok, response} = create_delete_request(target_id, params, ctx)
    %{body: body, status_code: status_code, headers: headers} = response

    case Jason.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  defp create_delete_request(target_id, params, ctx) do
    url =
      url() <>
        "/projects/" <>
        ctx.extra_args.project_id <>
        "/deployment_targets/" <> target_id <> "?" <> Plug.Conn.Query.encode(params)

    HTTPoison.delete(
      url,
      headers(ctx.extra_args)
    )
  end
end
