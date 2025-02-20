defmodule Router.Deployments.CreateTest do
  use ExUnit.Case
  use Plug.Test

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @default_project_id "92be1234-1234-4234-8234-123456789012"

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    Support.Stubs.reset()

    Support.Stubs.Feature.seed()
    Support.Stubs.RBAC.seed_data()
    Support.Stubs.build_shared_factories()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user, id: @default_project_id)

    Support.Stubs.Feature.enable_feature(org.id, :deployment_targets)

    {:ok,
     extra_args: %{
       "organization_id" => org.id,
       "project_id" => project.id,
       "requester_id" => user.id
     }}
  end

  describe "POST /deployment_targets/ - endpoint to create deployment target" do
    setup [:setup_target_params, :setup_secret_params]

    test "when params are valid but project mismatches org then returns not found", ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      user = Support.Stubs.User.create_default()
      project = Support.Stubs.Project.create(org, user)

      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      ctx = %{ctx | extra_args: Map.put(ctx.extra_args, "project_id", project.id)}
      params = create_params(ctx, target_params, UUID.uuid4(), env_vars, files)
      {status_code, _, body} = create_deployment(ctx, params)
      assert status_code == 404
      assert "Not found" = body
    end

    test "when params are valid then creates a new target", ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(ctx, target_params, UUID.uuid4(), env_vars, files)
      {status_code, _, body} = create_deployment(ctx, params)
      assert status_code == 200

      assert target_id = body["id"]

      conn = create_conn(ctx)
      {:ok, described} = PipelinesAPI.SecretClient.describe(%{"target_id" => target_id}, conn)

      expected = %{
        env_vars: [%{name: "VAR", value: "VALUE"}],
        files: [%{path: "FILE", content: Base.encode64("CONTENT")}]
      }

      assert ^described = expected

      target = Support.Stubs.DB.find(:deployment_targets, target_id)

      assert target != nil
      assert target.id == target_id
      assert length(target.api_model.subject_rules) == 2
      assert length(target.api_model.object_rules) == 2
    end

    test "when params are valid, but without subject and object rules, then creates a new target with default rules",
         ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      target_params =
        Map.merge(ctx.target_params, ctx.extra_args)
        |> Map.drop(["subject_rules", "object_rules"])

      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(ctx, target_params, UUID.uuid4(), env_vars, files)
      {status_code, _, body} = create_deployment(ctx, params)
      assert status_code == 200

      assert target_id = body["id"]

      conn = create_conn(ctx)
      {:ok, described} = PipelinesAPI.SecretClient.describe(%{"target_id" => target_id}, conn)

      expected = %{
        env_vars: [%{name: "VAR", value: "VALUE"}],
        files: [%{path: "FILE", content: Base.encode64("CONTENT")}]
      }

      assert ^described = expected

      target = Support.Stubs.DB.find(:deployment_targets, target_id)

      assert target != nil
      assert target.id == target_id
      assert length(target.api_model.subject_rules) == 1
      assert length(target.api_model.object_rules) == 3
    end

    test "when params are valid, but client has deployment targets feature but doesn't have advanced deployments targets feature enabled, it returns error",
         ctx do
      fake_org = "00000000-0000-4000-8000-000000000000"
      Support.Stubs.Feature.enable_feature(fake_org, :deployment_targets)
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", fake_org))

      target_params = Map.merge(ctx.extra_args, ctx.target_params)

      project_id = "10000000-0000-4000-8000-000000000000"

      params =
        create_params(ctx, target_params, UUID.uuid4(), [], [])
        |> Map.put("project_id", project_id)

      {status_code, _, message} = create_deployment(ctx, params)
      assert status_code == 403

      assert message ==
               "The advanced deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are valid, but client doesn't have advanced deployments targets feature enabled, it returns error",
         ctx do
      fake_org = "fake_org"
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", fake_org))
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      params = create_params(ctx, target_params, UUID.uuid4(), [], [])
      {status_code, _, message} = create_deployment(ctx, params)
      assert status_code == 403

      assert message ==
               "The advanced deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.deployment_targets.manage")
        )
      end)

      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      params = create_params(ctx, target_params, UUID.uuid4(), [], [])
      {status_code, _headers, message} = create_deployment(ctx, params)
      assert status_code == 401
      assert message == "Permission denied"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(ctx, target_params, UUID.uuid4(), env_vars, files)
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      {status_code, _headers, message} = create_deployment(ctx, params)
      assert status_code == 403

      assert message ==
               "The advanced deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are valid but subject rules have role not supported returns error", ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)

      params =
        create_params(ctx, target_params, UUID.uuid4(), [], [])
        |> Map.put("subject_rules", [
          %{"type" => "ROLE", "subject_id" => "not-supported"}
        ])

      {status_code, _, message} = create_deployment(ctx, params)
      assert status_code == 400
      assert message == "role \"not-supported\" is not valid"
    end

    test "when params are valid but subject rules have user with subject id not supported returns error",
         ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      user_id = "not-supported-user-id"

      params =
        create_params(ctx, target_params, UUID.uuid4(), [], [])
        |> Map.put("subject_rules", [
          %{"type" => "USER", "subject_id" => user_id}
        ])

      {status_code, _, message} = create_deployment(ctx, params)
      assert status_code == 400

      expected_message =
        "user \"" <>
          user_id <>
          "\" can't be added to subject rules for project \"" <>
          @default_project_id <>
          "\" and organization \"" <> @default_org_id <> "\""

      assert expected_message == message
    end

    test "when params are valid and subject rules has valid user's provider login then creates a new target",
         ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      target_params =
        Map.merge(ctx.target_params, ctx.extra_args)
        |> Map.delete("subject_rules")
        |> Map.put("subject_rules", [
          %{"type" => "USER", "git_login" => "milica-nerlovic"},
          %{"type" => "ROLE", "subject_id" => "admin"}
        ])

      params = create_params(ctx, target_params, UUID.uuid4(), [], [])
      {status_code, _, created_target} = create_deployment(ctx, params)
      assert status_code == 200

      assert [
               %{
                 "git_login" => "milica-nerlovic",
                 "subject_id" => ^subject_id,
                 "type" => "USER"
               },
               %{"subject_id" => "Admin", "type" => "ROLE"}
             ] = created_target["subject_rules"]

      target = Support.Stubs.DB.find(:deployment_targets, created_target["id"])
      assert target != nil
      assert length(target.api_model.subject_rules) == 2

      assert [
               %InternalApi.Gofer.DeploymentTargets.SubjectRule{
                 subject_id: subject_id,
                 type: 0
               },
               %InternalApi.Gofer.DeploymentTargets.SubjectRule{subject_id: "Admin", type: 1}
             ] == target.api_model.subject_rules

      assert length(target.api_model.object_rules) == 2
    end

    test "when params are valid and subject rules has invalid user's provider login then creates a new target",
         ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      target_params =
        Map.merge(ctx.target_params, ctx.extra_args)
        |> Map.delete("subject_rules")
        |> Map.put("subject_rules", [
          %{"type" => "USER", "git_login" => "milica-nerlovic-2"},
          %{"type" => "ROLE", "subject_id" => "admin"}
        ])

      params = create_params(ctx, target_params, UUID.uuid4(), [], [])
      {status_code, _, message} = create_deployment(ctx, params)
      assert status_code == 400
      assert "handle milica-nerlovic-2 can't be used as subject id" == message
    end

    test "when params are invalid and project_id is not valid UUID returns error", ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      target_params = Map.merge(ctx.target_params, ctx.extra_args)

      params =
        create_params(ctx, target_params, UUID.uuid4(), [], []) |> Map.put("project_id", "fakeId")

      {status_code, _, message} = create_deployment(ctx, params)

      assert status_code == 400
      assert message == "project id must be a valid UUID"
    end

    test "when params are invalid and project_id is missing returns error", ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      target_params = Map.merge(ctx.target_params, ctx.extra_args)

      params = create_params(ctx, target_params, UUID.uuid4(), [], []) |> Map.drop(["project_id"])

      {status_code, _, message} = create_deployment(ctx, params)

      assert status_code == 400
      assert message == "project_id must be present"
    end
  end

  defp create_params(ctx, target_params, unique_token, env_vars, files) do
    target_params
    |> Map.merge(%{
      "requester_id" => target_params["requester_id"],
      "env_vars" => env_vars,
      "files" => files,
      "unique_token" => unique_token,
      "project_id" => ctx.extra_args["project_id"]
    })
  end

  defp setup_target_params(ctx) do
    assert %{subject_id: subject_id} =
             Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

    {:ok,
     target_params: %{
       "id" => UUID.uuid4(),
       "name" => "Staging",
       "description" => "Staging environment",
       "url" => "https://staging.rtx.com",
       "subject_rules" => [
         %{"type" => "USER", "subject_id" => subject_id},
         %{"type" => "ROLE", "subject_id" => "admin"}
       ],
       "object_rules" => [
         %{"type" => 0, "match_mode" => 0, "pattern" => ""},
         %{"type" => 1, "match_mode" => 0, "pattern" => ""}
       ],
       "project_id" => ctx.extra_args["project_id"]
     }}
  end

  defp setup_secret_params(_ctx) do
    alias InternalApi.Secrethub.Secret.Data

    {:ok, encrypted_data} =
      Support.Stubs.Secret.Keys.encrypt(
        Util.Proto.deep_new!(Data, %{
          env_vars: [%{name: "VAR", value: "VALUE"}],
          files: [%{path: "FILE", content: "CONTENT"}]
        })
      )

    {:ok, secret_params: encrypted_data}
  end

  defp create_deployment(ctx, params) do
    res = post_create_request(params |> Poison.encode!(), ctx)
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

  defp post_create_request(params, ctx) do
    url = url() <> "/deployment_targets"

    HTTPoison.post(
      url,
      params,
      headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"])
    )
  end

  defp create_conn(ctx) do
    init_conn()
    |> put_req_header("x-semaphore-user-id", ctx.extra_args["requester_id"])
    |> put_req_header("x-semaphore-org-id", ctx.extra_args["organization_id"])
  end

  defp init_conn() do
    conn(:get, "/deployments")
  end
end
