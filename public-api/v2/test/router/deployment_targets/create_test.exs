defmodule Router.Deployments.CreateTest do
  use PublicAPI.Case
  use Plug.Test

  require Logger

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @org_without_feature UUID.uuid4()
  @default_project_id "92be1234-1234-4234-8234-123456789012"
  import Test.PipelinesClient, only: [headers: 1, url: 0]

  setup do
    on_exit(fn ->
      Support.Stubs.reset()
    end)

    Support.Stubs.reset()
    Support.Stubs.RBAC.seed_data()
    Support.Stubs.User.create_default()

    project_id = @default_project_id
    user_id = UUID.uuid4()
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
       project_id: @default_project_id,
       requester_id: user_id,
       user_id: user_id
     }}
  end

  describe "authorized user to create deployment target" do
    setup [:setup_target_params, :setup_secret_params]

    test "when params are valid then creates a new target", ctx do
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(ctx, target_params, UUID.uuid4(), env_vars, files)
      {status_code, _, body} = create_deployment(ctx, params)
      assert status_code == 200

      assert target_id = body["metadata"]["id"]

      {:ok, described} =
        InternalClients.Secrets.describe(%{
          deployment_target_id: target_id,
          user_id: ctx.extra_args.user_id,
          organization_id: ctx.extra_args.org_id,
          secret_level: :DEPLOYMENT_TARGET
        })

      assert length(described.spec.data.env_vars) == 1
      assert length(described.spec.data.files) == 1

      target = Support.Stubs.DB.find(:deployment_targets, target_id)

      assert target != nil
      assert target.id == target_id
      assert length(target.api_model.subject_rules) == 2
      assert length(target.api_model.object_rules) == 2
    end

    test "when params are valid, with secret, then creates a new target with default rules",
         ctx do
      target_params = Map.merge(ctx.target_params, ctx.extra_args)

      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]

      params = create_params(ctx, target_params, UUID.uuid4(), env_vars, files)
      {status_code, _, body} = create_deployment(ctx, params)
      assert status_code == 200

      assert target_id = body["metadata"]["id"]

      {:ok, described} =
        InternalClients.Secrets.describe(%{
          deployment_target_id: target_id,
          user_id: ctx.extra_args.user_id,
          organization_id: ctx.extra_args.org_id,
          secret_level: :DEPLOYMENT_TARGET
        })

      assert length(described.spec.data.env_vars) == 1
      assert length(described.spec.data.files) == 1

      target = Support.Stubs.DB.find(:deployment_targets, target_id)

      assert target != nil
      assert target.id == target_id
    end

    test "when params are valid, but client has deployment targets feature but doesn't have advanced deployments targets feature enabled, it returns error",
         ctx do
      fake_org = UUID.uuid4()
      Support.Stubs.Feature.disable_feature(fake_org, "advanced_deployment_targets")

      PermissionPatrol.add_permissions(
        fake_org,
        ctx.extra_args.user_id,
        "project.deployment_targets.manage",
        ctx.extra_args.project_id
      )

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :org_id, fake_org))

      target_params = ctx.target_params

      params = create_params(target_params, UUID.uuid4(), [], [])

      {status_code, _, message} = create_deployment(ctx, params)
      assert status_code == 404

      assert message["message"] ==
               "The advanced deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are valid, but client doesn't have advanced deployments targets feature enabled, it returns error",
         ctx do
      fake_org = UUID.uuid4()
      Support.Stubs.Feature.disable_feature(fake_org, "advanced_deployment_targets")
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :org_id, fake_org))
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      params = create_params(ctx, target_params, UUID.uuid4(), [], [])
      {status_code, _, message} = create_deployment(ctx, params)
      assert status_code == 404

      assert message["message"] ==
               "The advanced deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are valid but user is not authorized then returns error", ctx do
      user_id = UUID.uuid4()

      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      params = create_params(ctx, target_params, UUID.uuid4(), [], [])
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :requester_id, user_id))
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :user_id, user_id))
      {status_code, _headers, message} = create_deployment(ctx, params)
      assert status_code == 404
      assert message["message"] =~ "Not Found"
    end

    test "when params are valid but organization doesn't have feature enabled then returns error",
         ctx do
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :org_id, @org_without_feature))
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(ctx, target_params, UUID.uuid4(), env_vars, files)
      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :requester_id, UUID.uuid4()))
      {status_code, _headers, message} = create_deployment(ctx, params)
      assert status_code == 404

      assert message["message"] ==
               "The advanced deployment targets feature is not enabled for your organization. See more details here: https://semaphoreci.com/pricing"
    end

    test "when params are valid and subject rules has valid user's provider login then creates a new target",
         ctx do
      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      deployment_target = Map.merge(ctx.target_params, ctx.extra_args)

      target_spec =
        deployment_target.spec
        |> Map.put(:subject_rules, %{
          users: ["milica-nerlovic"],
          roles: ["admin"]
        })

      target_params = %{
        deployment_target
        | spec: target_spec
      }

      params = create_params(ctx, target_params, UUID.uuid4(), [], [])
      {status_code, _, created_target} = create_deployment(ctx, params)
      assert status_code == 200

      assert %{"users" => ["milica-nerlovic"], "roles" => ["Admin"]} =
               created_target["spec"]["subject_rules"]

      target = Support.Stubs.DB.find(:deployment_targets, created_target["metadata"]["id"])
      assert target != nil
      assert length(target.api_model.subject_rules) == 2

      assert [
               %InternalApi.Gofer.DeploymentTargets.SubjectRule{
                 subject_id: subject_id,
                 type: :USER
               },
               %InternalApi.Gofer.DeploymentTargets.SubjectRule{subject_id: "Admin", type: :ROLE}
             ] == target.api_model.subject_rules

      assert length(target.api_model.object_rules) == 2
    end

    test "when params are valid and subject rules has invalid user's provider login responds with error",
         ctx do
      deployment_target = Map.merge(ctx.target_params, ctx.extra_args)

      target_spec =
        deployment_target.spec
        |> Map.put(:subject_rules, %{
          users: ["milica-nerlovic-2"],
          roles: ["admin"]
        })

      target_params = %{
        deployment_target
        | spec: target_spec
      }

      params = create_params(ctx, target_params, UUID.uuid4(), [], [])
      {status_code, _, message} = create_deployment(ctx, params)
      assert status_code == 400

      assert "User milica-nerlovic-2 does not exist or is not a member of the project" ==
               message["message"]
    end

    test "when params are invalid and project_id is not valid UUID returns error", ctx do
      target_params = Map.merge(ctx.target_params, ctx.extra_args)

      params = create_params(ctx, target_params, UUID.uuid4(), [], [])

      ctx = Map.put(ctx, :extra_args, Map.put(ctx.extra_args, :project_id, "fakeId"))

      {status_code, _, message} = create_deployment(ctx, params)

      assert status_code == 404
      assert message["message"] =~ "Project not found"
    end
  end

  # todo: cleanup create_params
  defp create_params(_, target_params, unique_token, env_vars, files),
    do: create_params(target_params, unique_token, env_vars, files)

  defp create_params(target_params, unique_token, env_vars, files) do
    dt_spec =
      target_params.spec
      |> Map.merge(%{
        name: "Staging",
        env_vars: env_vars,
        files: files
      })

    %{
      deployment_target: %{target_params | spec: dt_spec},
      unique_token: unique_token
    }
  end

  defp setup_target_params(_ctx) do
    assert %{subject_id: subject_id} =
             Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

    {:ok,
     target_params: %{
       apiVersion: "v2",
       kind: "DeploymentTarget",
       spec: %{
         name: "Staging",
         description: "Staging environment",
         url: "https://staging.rtx.com",
         subject_rules: %{
           users: [subject_id],
           roles: ["admin"]
         },
         object_rules: %{
           branches: "ALL",
           tags: [%{match_mode: "REGEX", pattern: "A"}]
         }
       }
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
    {:ok, response} = post_create_request(params |> Jason.encode!(), ctx)
    %{body: body, status_code: status_code, headers: headers} = response

    case Jason.decode(body) do
      {:ok, decoded} -> {status_code, headers, decoded}
      _ -> {status_code, headers, body}
    end
  end

  defp post_create_request(params, ctx) do
    url = url() <> "/projects/#{ctx.extra_args.project_id}/deployment_targets"

    HTTPoison.post(
      url,
      params,
      headers(ctx.extra_args)
    )
  end
end
