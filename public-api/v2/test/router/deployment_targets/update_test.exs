defmodule Router.Deployments.UpdateTest do
  use PublicAPI.Case

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @default_project_id "92be1234-1234-4234-8234-123456789012"
  @org_without_feature UUID.uuid4()
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

  describe "PATCH /deployment_targets/ - endpoint to update deployment target" do
    setup [:setup_target_params, :setup_secret_params, :create_dt]

    test "when params are valid then updates the target", ctx do
      target = ctx.target

      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      params = %{
        deployment_target: %{
          apiVersion: "v2",
          kind: "DeploymentTarget",
          spec: %{
            "name" => "Changed_Name",
            # "organization_id" => ctx.extra_args.org_id,
            # "project_id" => ctx.extra_args.project_id,
            "subject_rules" => %{
              users: [subject_id],
              roles: ["admin"]
            },
            "env_vars" => [
              %{
                "name" => "VAR",
                "value" => "CHANGED VALUE"
              },
              %{
                "name" => "VAR2",
                "value" => "VALUE2"
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
            ]
          }
        },
        unique_token: UUID.uuid4()
      }

      assert {status_code, _headers, updated_target} = update_deployment(target.id, ctx, params)

      assert status_code == 200
      assert updated_target["spec"]["name"] == "Changed_Name"

      %{api_model: secret} = Support.Stubs.DB.find_by(:deployment_secrets, :dt_id, target.id)

      expected_env_vars = [
        %InternalApi.Secrethub.Secret.EnvVar{name: "VAR", value: "CHANGED VALUE"},
        %InternalApi.Secrethub.Secret.EnvVar{name: "VAR2", value: "VALUE2"}
      ]

      expected_files = [
        %InternalApi.Secrethub.Secret.File{path: "NEWFILE", content: Base.encode64("NEWCONTENT")},
        %InternalApi.Secrethub.Secret.File{path: "FILE", content: Base.encode64("CONTENT")}
      ]

      assert ^expected_env_vars = secret.data.env_vars
      assert ^expected_files = secret.data.files
    end

    test "when params are valid but target doesn't exist then updates the target", ctx do
      fake_id = "00000000-0000-4000-8000-000000000000"

      params = %{
        deployment_target: %{
          apiVersion: "v2",
          kind: "DeploymentTarget",
          spec: %{
            "name" => "Changed_Name",
            "env_vars" => [%{"name" => "VAR", "value" => "CHANGED VALUE"}]
          }
        },
        unique_token: UUID.uuid4()
      }

      assert {status_code, _headers, message} = update_deployment(fake_id, ctx, params)
      require Logger

      assert status_code == 404
      assert message["message"] == "Not found"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      org_id = UUID.uuid4()
      Support.Stubs.Feature.disable_feature(org_id, "deployment_targets")
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :org_id, org_id))

      fake_id = "00000000-0000-4000-8000-000000000000"

      params = %{
        deployment_target: %{
          apiVersion: "v2",
          kind: "DeploymentTarget",
          spec: %{
            "name" => "Changed Name",
            "env_vars" => [%{"name" => "VAR", "value" => "CHANGED VALUE"}]
          }
        },
        unique_token: UUID.uuid4()
      }

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, "requester_id", "fail_user_id"))
      assert {status_code, _headers, message} = update_deployment(fake_id, ctx, params)
      assert status_code == 404

      assert message["message"] ==
               "The deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when updating DT that is not owned by requester org", ctx do
      Support.Stubs.Deployments.Grpc.mock_wrong_org(UUID.uuid4())

      params = %{
        deployment_target: %{
          apiVersion: "v2",
          kind: "DeploymentTarget",
          spec: %{
            "name" => "Changed_Name",
            "env_vars" => [%{"name" => "VAR", "value" => "CHANGED VALUE"}]
          }
        },
        unique_token: UUID.uuid4()
      }

      assert {status_code, _headers, _message} = update_deployment(ctx.target.id, ctx, params)
      assert status_code == 404
    end
  end

  defp setup_target_params(ctx) do
    {:ok,
     target_params: %{
       id: UUID.uuid4(),
       description: "Staging environment",
       url: "https://staging.rtx.com",
       object_rules: [
         %{type: :BRANCH, match_mode: :ALL, pattern: ""},
         %{type: :TAG, match_mode: :EXACT, pattern: ""}
       ],
       project_id: ctx.extra_args.project_id
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

  defp create_dt(ctx) do
    {target, secret} =
      Support.Stubs.Deployments.create(
        %{id: ctx.extra_args.project_id, org_id: ctx.extra_args.org_id},
        %{id: ctx.extra_args.user_id},
        "Staging",
        ctx.target_params
      )

    {:ok, target: target, secret: secret}
  end

  defp update_deployment(target_id, ctx, params) do
    res = patch_update_request(target_id, params |> Jason.encode!(), ctx)
    {:ok, response} = res
    %{body: body, status_code: status_code, headers: headers} = response

    case Jason.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  defp patch_update_request(target_id, params, ctx) do
    url =
      url() <> "/projects/" <> ctx.extra_args.project_id <> "/deployment_targets/" <> target_id

    HTTPoison.patch(
      url,
      params,
      headers(ctx.extra_args)
    )
  end
end
