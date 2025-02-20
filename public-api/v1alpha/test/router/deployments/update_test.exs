defmodule Router.Deployments.UpdateTest do
  use Plug.Test
  use ExUnit.Case

  alias PipelinesAPI.Validator
  alias PipelinesAPI.DeploymentsClient
  alias PipelinesAPI.SecretClient

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @default_project_id "92be1234-1234-4234-8234-123456789012"

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    Support.Stubs.reset()
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

  describe "PATCH /deployment_targets/ - endpoint to update deployment target" do
    setup [:setup_target_params, :setup_secret_params]

    test "project ID mismatch - 404", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      user = Support.Stubs.User.create_default()
      project = Support.Stubs.Project.create(org, user)

      Support.Stubs.Feature.enable_feature(org.id, :advanced_deployment_targets)

      extra_args = %{
        "organization_id" => org.id,
        "project_id" => project.id,
        "requester_id" => user.id
      }

      old_ctx = ctx
      ctx = %{ctx | extra_args: extra_args}

      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          [],
          [],
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      assert %{subject_id: _} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "unique_token" => UUID.uuid4()
      }

      assert {404, _headers, "Not found"} = update_deployment(target.id, old_ctx, params)
    end

    test "no permission -> 401", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.deployment_targets.manage")
        )
      end)

      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          [],
          [],
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      assert %{subject_id: _} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "unique_token" => UUID.uuid4()
      }

      assert {401, _headers, "Permission denied"} = update_deployment(target.id, ctx, params)
    end

    test "when params are valid then updates the target", ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()

      env_vars = [
        %{"name" => "VAR", "value" => "VALUE"},
        %{"name" => "VAR2", "value" => "VALUE2"}
      ]

      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          env_vars,
          files,
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "subject_rules" => [
          %{"type" => "USER", "subject_id" => subject_id},
          %{"type" => "ROLE", "subject_id" => "admin"}
        ],
        "env_vars" => [
          %{
            "name" => "VAR",
            "value" => "CHANGED VALUE"
          },
          %{
            "name" => "VAR2",
            "value" => Validator.hide_secret("VALUE2")
          }
        ],
        "files" => [
          %{
            "path" => "NEWFILE",
            "content" => Base.encode64("NEWCONTENT")
          },
          %{
            "path" => "FILE",
            "content" => Base.encode64("CONTENT")
          }
        ],
        "unique_token" => UUID.uuid4()
      }

      assert {status_code, _headers, updated_target} = update_deployment(target.id, ctx, params)

      assert status_code == 200
      assert updated_target["name"] == "Changed Name"

      {:ok, described} =
        PipelinesAPI.SecretClient.describe(%{"target_id" => updated_target["id"]}, conn)

      expected_env_vars = [
        %{name: "VAR", value: "CHANGED VALUE"},
        %{name: "VAR2", value: "VALUE2"}
      ]

      expected_files = [
        %{path: "FILE", content: Base.encode64("CONTENT")},
        %{path: "NEWFILE", content: Base.encode64("NEWCONTENT")}
      ]

      assert ^expected_env_vars = described.env_vars
      assert ^expected_files = described.files
    end

    test "when params but is missing advanced deployments feature it returns error", ctx do
      fake_org = "fake_org"
      Support.Stubs.Feature.enable_feature(fake_org, :deployment_targets)
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", fake_org))

      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          [],
          [],
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "subject_rules" => [
          %{"type" => 0, "subject_id" => UUID.uuid4()},
          %{"type" => 1, "subject_id" => UUID.uuid4()}
        ],
        "unique_token" => UUID.uuid4()
      }

      assert {status_code, _, message} = update_deployment(target.id, ctx, params)

      assert status_code == 403

      assert message ==
               "The advanced deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are valid and target has project_id, but project_id is missing from request then updates the target",
         ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          env_vars,
          files,
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "env_vars" => [%{"name" => "VAR", "value" => "CHANGED VALUE"}],
        "unique_token" => UUID.uuid4()
      }

      assert {status_code, _headers, updated_target} = update_deployment(target.id, ctx, params)
      assert status_code == 200
      assert updated_target["name"] == "Changed Name"
    end

    test "when params are valid but target doesn't exist then updates the target", ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          env_vars,
          files,
          key
        )

      assert {:ok, _} = DeploymentsClient.create(params, conn)

      fake_id = "00000000-0000-4000-8000-000000000000"

      params = %{
        "id" => fake_id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "env_vars" => [%{"name" => "VAR", "value" => "CHANGED VALUE"}],
        "unique_token" => UUID.uuid4()
      }

      assert {status_code, _headers, message} = update_deployment(fake_id, ctx, params)
      assert status_code == 404
      assert message == "Target not found"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))

      fake_id = "00000000-0000-4000-8000-000000000000"

      params = %{
        "id" => fake_id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "env_vars" => [%{"name" => "VAR", "value" => "CHANGED VALUE"}],
        "unique_token" => UUID.uuid4()
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      assert {status_code, _headers, message} = update_deployment(fake_id, ctx, params)
      assert status_code == 403

      assert message ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are valid but subject rules have role which is not supported returns error",
         ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          [],
          [],
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "subject_rules" => [
          %{"type" => "ROLE", "subject_id" => "not-supported"}
        ],
        "unique_token" => UUID.uuid4()
      }

      assert {status_code, _headers, message} = update_deployment(target.id, ctx, params)

      assert status_code == 400
      assert message == "role \"not-supported\" is not valid"
    end

    test "when params are valid but subject rules have user with subject id which is not supported returns error",
         ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          [],
          [],
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      user_id = "not-supported-user-id"

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "subject_rules" => [
          %{"type" => "USER", "subject_id" => user_id}
        ],
        "unique_token" => UUID.uuid4()
      }

      assert {status_code, _headers, message} = update_deployment(target.id, ctx, params)

      assert status_code == 400

      expected_message =
        "user \"" <>
          user_id <>
          "\" can't be added to subject rules for project \"" <>
          @default_project_id <>
          "\" and organization \"" <> @default_org_id <> "\""

      assert expected_message == message
    end

    test "when params are valid and subject rules contain valid provider login then updates the target",
         ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          [],
          [],
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "subject_rules" => [
          %{"type" => "USER", "git_login" => "milica-nerlovic"},
          %{"type" => "ROLE", "subject_id" => "admin"}
        ],
        "unique_token" => UUID.uuid4()
      }

      assert {status_code, _headers, updated_target} = update_deployment(target.id, ctx, params)

      assert status_code == 200

      assert [
               %{"git_login" => "milica-nerlovic", "subject_id" => subject_id, "type" => "USER"},
               %{"subject_id" => "Admin", "type" => "ROLE"}
             ] == updated_target["subject_rules"]
    end

    test "when params are valid and subject rules contain invalid provider login then updates the target",
         ctx do
      Support.Stubs.Feature.enable_feature(@default_org_id, :advanced_deployment_targets)

      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()

      params =
        create_params(
          ctx,
          target_params,
          UUID.uuid4(),
          ctx.extra_args["requester_id"],
          [],
          [],
          key
        )

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      assert %{subject_id: _subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      params = %{
        "id" => target.id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "subject_rules" => [
          %{"type" => "USER", "git_login" => "milica-nerlovic-2"},
          %{"type" => "ROLE", "subject_id" => "admin"}
        ],
        "unique_token" => UUID.uuid4()
      }

      assert {status_code, _headers, message} = update_deployment(target.id, ctx, params)

      assert status_code == 400
      assert "handle milica-nerlovic-2 can't be used as subject id" == message
    end

    test "when params are not valid because target_id is not UUIDit returns error",
         ctx do
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "organization_id", "fakeOrg"))

      fake_id = "00000000-0000-4000-0000-00000000000"

      params = %{
        "id" => fake_id,
        "name" => "Changed Name",
        "organization_id" => ctx.extra_args["organization_id"],
        "project_id" => ctx.extra_args["project_id"],
        "env_vars" => [%{"name" => "VAR", "value" => "CHANGED VALUE"}],
        "unique_token" => UUID.uuid4()
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      assert {status_code, _headers, message} = update_deployment(fake_id, ctx, params)
      assert status_code == 400

      assert message ==
               "target_id must be a valid UUID"
    end
  end

  defp create_params(ctx, target_params, unique_token, requester_id, env_vars, files, key) do
    target_params
    |> Map.merge(%{
      "requester_id" => requester_id,
      "env_vars" => env_vars,
      "files" => files,
      "unique_token" => unique_token,
      "project_id" => ctx.extra_args["project_id"],
      "key" => key
    })
  end

  defp setup_target_params(ctx) do
    {:ok,
     target_params: %{
       "id" => UUID.uuid4(),
       "name" => "Staging",
       "description" => "Staging environment",
       "url" => "https://staging.rtx.com",
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

  defp update_deployment(target_id, ctx, params) do
    res = patch_update_request(target_id, params |> Poison.encode!(), ctx)
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

  defp patch_update_request(target_id, params, ctx) do
    url = url() <> "/deployment_targets/" <> target_id

    HTTPoison.patch(
      url,
      params,
      headers(ctx.extra_args["requester_id"], ctx.extra_args["organization_id"])
    )
  end

  defp create_conn(ctx) do
    conn(:post, "/deployment_targets")
    |> put_req_header("x-semaphore-user-id", ctx.extra_args["requester_id"])
    |> put_req_header("x-semaphore-org-id", ctx.extra_args["organization_id"])
  end
end
