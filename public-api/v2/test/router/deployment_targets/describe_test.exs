defmodule Router.Deployments.DescribeTest do
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
      "project.deployment_targets.view",
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

  describe "GET /deployment_targets - endpoint returns the deployment" do
    setup [:setup_three_targets]

    test "when params are valid and target exists by id it describes a target", ctx do
      target_name = "target1"

      [target] =
        Support.Stubs.DB.filter(:deployment_targets,
          project_id: ctx.extra_args.project_id,
          name: target_name
        )

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args.project_id
      }

      {status_code, _headers, described} = get_describe(ctx, params)

      assert status_code == 200
      assert described["metadata"]["name"] == target.name
      assert described["metadata"]["project_id"] == target.project_id
    end

    test "when params are valid and target exists by id it describes a target and returns secrets",
         ctx do
      target_name = "target1"

      [target] =
        Support.Stubs.DB.filter(:deployment_targets,
          project_id: ctx.extra_args.project_id,
          name: target_name
        )

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args.project_id,
        "include_secrets" => true
      }

      {status_code, _headers, described} = get_describe(ctx, params)

      assert status_code == 200
      assert described["metadata"]["name"] == target.name
      assert described["metadata"]["project_id"] == target.project_id
      assert described["spec"]["active"] == true

      expected_env_vars = [
        %{"name" => "X", "value" => value_md5("123")}
      ]

      expected_files = [
        %{
          "path" => "/lib/code.ex",
          "content" => value_md5("abc")
        }
      ]

      assert ^expected_env_vars = described["spec"]["env_vars"]
      assert ^expected_files = described["spec"]["files"]
    end

    test "when params are valid and target doesn't exist it returns an error", ctx do
      target_id = "00000000-0000-4000-8000-000000000000"

      params = %{
        "target_id" => target_id,
        "project_id" => ctx.extra_args.project_id
      }

      {status_code, _headers, body} = get_describe(ctx, params)
      assert status_code == 404
      assert body["message"] == "Not found"
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      target_name = "target1"

      params = %{
        "target_name" => target_name,
        "project_id" => ctx.extra_args.project_id
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :user_id, UUID.uuid4()))
      {status_code, _headers, message} = get_describe(ctx, params)
      assert status_code == 404
      assert "Not Found" =~ message["message"]
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      target_name = "target1"
      org_id = UUID.uuid4()
      Support.Stubs.Feature.disable_feature(org_id, "deployment_targets")
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :org_id, org_id))

      params = %{
        "target_name" => target_name,
        "project_id" => ctx.extra_args.project_id
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :user_id, UUID.uuid4()))
      {status_code, _headers, message} = get_describe(ctx, params)
      assert status_code == 404

      assert message["message"] ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when requester org is not the owner of the deployment target", ctx do
      [target] =
        Support.Stubs.DB.filter(:deployment_targets,
          project_id: ctx.extra_args.project_id,
          name: "target1"
        )

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args.project_id
      }

      Support.Stubs.Deployments.Grpc.mock_wrong_org(UUID.uuid4())

      {status_code, _headers, message} = get_describe(ctx, params)
      assert status_code == 404
      assert %{"message" => "Not found"} = message
    end

    test "when requester has no permission on project_id", ctx do
      [target] =
        Support.Stubs.DB.filter(:deployment_targets,
          project_id: ctx.extra_args.project_id,
          name: "target1"
        )

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args.project_id
      }

      Support.Stubs.Deployments.Grpc.mock_wrong_project(UUID.uuid4())

      {status_code, _headers, message} = get_describe(ctx, params)
      assert status_code == 404
      assert %{"message" => "Not found"} = message
    end

    test "when requester has no permission on project", ctx do
      [target] =
        Support.Stubs.DB.filter(:deployment_targets,
          project_id: ctx.extra_args.project_id,
          name: "target1"
        )

      params = %{
        "target_id" => target.id,
        "project_id" => ctx.extra_args.project_id
      }

      Support.Stubs.Deployments.Grpc.mock_wrong_project(UUID.uuid4())

      {status_code, _headers, message} = get_describe(ctx, params)
      assert status_code == 404
      assert %{"message" => "Not found"} = message
    end
  end

  defp setup_three_targets(ctx) do
    project = %{org_id: ctx.extra_args.org_id, id: ctx.extra_args.project_id}
    user = %{id: ctx.extra_args.requester_id}

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

    case Jason.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  defp get_describe_request(params, ctx) do
    url = url() <> get_path(params) <> "?with_credentials=#{params["include_secrets"] || false}"

    HTTPoison.get(url, headers(ctx.extra_args))
  end

  defp value_md5(value) do
    :erlang.md5(value)
    |> Base.encode64()
  end

  defp get_path(%{"target_id" => target_id, "project_id" => project_id}) do
    "/projects/" <> project_id <> "/deployment_targets/" <> target_id
  end

  defp get_path(%{"target_name" => target_name, "project_id" => project_id}) do
    "/projects/" <> project_id <> "/deployment_targets/" <> target_name
  end
end
