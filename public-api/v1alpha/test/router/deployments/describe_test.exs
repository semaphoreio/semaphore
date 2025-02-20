defmodule Router.Deployments.DescribeTest do
  use ExUnit.Case

  alias PipelinesAPI.Validator

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

  describe "GET /deployment_targets" do
    test "when params are valid but project ID mismatches then returns 404", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      user = Support.Stubs.User.create_default()
      project = Support.Stubs.Project.create(org, user)

      {target, _secret} =
        Support.Stubs.Deployments.create(project, user, "target1", %{
          env_vars: [%{name: "X", value: "123"}],
          files: [%{path: "/lib/code.ex", content: "abc"}]
        })

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args["project_id"]
      }

      assert {404, _headers, "Not found"} = get_describe(ctx, params)
      assert {404, _headers, "Not found"} = get_describe(ctx, %{"target_id" => target.id})
    end
  end

  describe "GET /deployment_targets - endpoint returns the deployment" do
    setup [:setup_three_targets]

    test "when params are valid and target exists by id it describes a target", ctx do
      target_name = "target1"

      [target] =
        Support.Stubs.DB.filter(:deployment_targets,
          project_id: ctx.extra_args["project_id"],
          name: target_name
        )

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, described} = get_describe(ctx, params)

      assert status_code == 200
      assert described["name"] == target.name
      assert described["project_id"] == target.project_id
    end

    test "when params are valid and target exists by id it describes a target and returns secrets",
         ctx do
      target_name = "target1"

      [target] =
        Support.Stubs.DB.filter(:deployment_targets,
          project_id: ctx.extra_args["project_id"],
          name: target_name
        )

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args["project_id"],
        "include_secrets" => true
      }

      {status_code, _headers, described} = get_describe(ctx, params)

      assert status_code == 200
      assert described["name"] == target.name
      assert described["project_id"] == target.project_id
      assert described["active"] == true

      expected_env_vars = [
        %{"name" => "X", "value" => Validator.hide_secret("123")}
      ]

      expected_files = [
        %{
          "path" => "/lib/code.ex",
          "content" => Validator.hide_secret("abc")
        }
      ]

      assert ^expected_env_vars = described["env_vars"]
      assert ^expected_files = described["files"]
    end

    test "when params are valid and target exists by id and project_id is missing it describes a target",
         ctx do
      target_name = "target1"

      [target] =
        Support.Stubs.DB.filter(:deployment_targets,
          project_id: ctx.extra_args["project_id"],
          name: target_name
        )

      params = %{
        "target_id" => target.id
      }

      {status_code, _headers, described} = get_describe(ctx, params)

      assert status_code == 200
      assert described["name"] == target.name
      assert described["project_id"] == target.project_id
      assert described["active"] == true
    end

    test "when params are valid and target doesn't exist it returns an error", ctx do
      target_id = "00000000-0000-4000-8000-000000000000"

      params = %{
        "target_id" => target_id,
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, body} = get_describe(ctx, params)
      assert status_code == 404
      assert body == "Target not found"
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.deployment_targets.view")
        )
      end)

      target_name = "target1"

      params = %{
        "target_name" => target_name,
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, message} = get_describe(ctx, params)
      assert status_code == 401
      assert message == "Permission denied"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      target_name = "target1"
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))

      params = %{
        "target_name" => target_name,
        "project_id" => ctx.extra_args["project_id"]
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      {status_code, _headers, message} = get_describe(ctx, params)
      assert status_code == 403

      assert message ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are invalid and target_id is not valid UUID it returns an error", ctx do
      target_id = "fakeId"

      params = %{
        "target_id" => target_id,
        "project_id" => ctx.extra_args["project_id"]
      }

      {status_code, _headers, body} = get_describe(ctx, params)
      assert status_code == 400
      assert body == "target_id must be a valid UUID"
    end
  end

  defp setup_three_targets(ctx) do
    project = %{org_id: ctx.extra_args["organization_id"], id: ctx.extra_args["project_id"]}
    user = %{id: ctx.extra_args["requester_id"]}

    for i <- 1..3 do
      Support.Stubs.Deployments.create(project, user, "target#{i}", %{
        env_vars: [%{name: "X", value: "123"}],
        files: [%{path: "/lib/code.ex", content: "abc"}]
      })
    end

    {:ok, project_id: project.id}
  end

  defp get_describe(ctx, params) do
    {:ok, response} = get_describe_request(params, ctx)

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

  defp get_describe_request(params, ctx) do
    url = url() <> get_path(params)

    HTTPoison.get(url, headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"]))
  end

  defp get_path(_params = %{"target_id" => target_id, "include_secrets" => include_secrets}) do
    "/deployment_targets/" <>
      target_id <>
      "?include_secrets=" <> "#{include_secrets}"
  end

  defp get_path(_params = %{"target_id" => target_id}), do: "/deployment_targets/" <> target_id

  defp get_path(%{"target_name" => target_name, "project_id" => project_id}) do
    "/deployment_targets?project_id=" <> project_id <> "&target_name=" <> target_name
  end
end
