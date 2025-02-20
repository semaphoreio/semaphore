defmodule Router.Deployments.DeleteTest do
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

  describe "DELETE /deployment_targets/ - endpoint to delete deployment target" do
    test "when project ID mismatches then returns 404", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      user = Support.Stubs.User.create_default()
      project = Support.Stubs.Project.create(org, user)
      target_id = UUID.uuid4()

      params = %{
        :unique_token => UUID.uuid4(),
        :organization_id => org.id,
        :requester_id => user.id,
        :project_id => project.id
      }

      Support.Stubs.DB.insert(:deployment_targets, %{
        id: target_id,
        project_id: ctx.extra_args["project_id"],
        name: "TargetName",
        unique_token: params["unique_token"],
        api_model:
          Util.Proto.deep_new!(InternalApi.Gofer.DeploymentTargets.DeploymentTarget, params),
        history: []
      })

      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target != nil
      assert target.id == target_id

      assert {_status_code, _headers, "Not found"} = delete_deployment(target_id, ctx, params)
    end

    test "when params are valid then deletes the target", ctx do
      target_id = UUID.uuid4()

      params = %{
        :unique_token => UUID.uuid4(),
        :organization_id => ctx.extra_args["organization_id"],
        :requester_id => ctx.extra_args["requester_id"],
        :project_id => ctx.extra_args["project_id"]
      }

      Support.Stubs.DB.insert(:deployment_targets, %{
        id: target_id,
        project_id: ctx.extra_args["project_id"],
        name: "TargetName",
        unique_token: params["unique_token"],
        api_model:
          Util.Proto.deep_new!(InternalApi.Gofer.DeploymentTargets.DeploymentTarget, params),
        history: []
      })

      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target != nil
      assert target.id == target_id

      assert {status_code, _headers, %{"target_id" => target_deleted_id}} =
               delete_deployment(target_id, ctx, params)

      assert status_code == 200
      assert target.id == target_deleted_id
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target == nil
    end

    test "when params are valid, project id is provided, and target doesn't exist it returns error",
         ctx do
      target_id = UUID.uuid4()

      params = %{
        :unique_token => UUID.uuid4(),
        :organization_id => ctx.extra_args["organization_id"],
        :requester_id => ctx.extra_args["requester_id"],
        :project_id => ctx.extra_args["project_id"]
      }

      assert {status_code, _headers, message} = delete_deployment(target_id, ctx, params)

      assert status_code == 404
      assert message == "Target not found"
    end

    test "when params are valid, project id is NOT provided, and target doesn't exist it returns not found",
         ctx do
      target_id = UUID.uuid4()

      params = %{
        :unique_token => UUID.uuid4(),
        :organization_id => ctx.extra_args["organization_id"],
        :requester_id => ctx.extra_args["requester_id"],
        :project_id => ctx.extra_args["project_id"]
      }

      assert {status_code, _headers, message} = delete_deployment(target_id, ctx, params)

      assert status_code == 404
      assert message == "Target not found"
    end

    test "when unique token is missing it doesn't delete the target", ctx do
      target_id = UUID.uuid4()

      params = %{
        :organization_id => ctx.extra_args["organization_id"],
        :requester_id => ctx.extra_args["requester_id"],
        :project_id => ctx.extra_args["project_id"]
      }

      Support.Stubs.DB.insert(:deployment_targets, %{
        id: target_id,
        project_id: ctx.extra_args["project_id"],
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

      assert status_code == 400

      assert message ==
               "target_id and unique_token are required to delete a deployment target"

      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target != nil
      assert target.id == target_id
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.deployment_targets.manage")
        )
      end)

      target_id = UUID.uuid4()

      params = %{
        :unique_token => UUID.uuid4(),
        :organization_id => ctx.extra_args["organization_id"],
        :requester_id => ctx.extra_args["requester_id"],
        :project_id => ctx.extra_args["project_id"]
      }

      Support.Stubs.DB.insert(:deployment_targets, %{
        id: target_id,
        project_id: ctx.extra_args["project_id"],
        name: "TargetName",
        unique_token: params["unique_token"],
        api_model:
          Util.Proto.deep_new!(InternalApi.Gofer.DeploymentTargets.DeploymentTarget, params),
        history: []
      })

      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      assert target != nil
      assert target.id == target_id

      {status_code, _headers, message} = delete_deployment(target_id, ctx, params)
      assert status_code == 401
      assert message == "Permission denied"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      target_id = UUID.uuid4()
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))

      params = %{
        :unique_token => UUID.uuid4(),
        :organization_id => ctx.extra_args["organization_id"],
        :requester_id => ctx.extra_args["requester_id"],
        :project_id => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = delete_deployment(target_id, ctx, params)
      assert status_code == 403

      assert message ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end
  end

  defp delete_deployment(target_id, ctx, params) do
    {:ok, response} = create_delete_request(target_id, params, ctx)
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

  defp create_delete_request(target_id, params, ctx) do
    url = url() <> "/deployment_targets/" <> target_id <> "?" <> Plug.Conn.Query.encode(params)

    HTTPoison.delete(
      url,
      headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"])
    )
  end
end
