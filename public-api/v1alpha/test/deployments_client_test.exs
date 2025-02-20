defmodule PipelinesAPI.DeploymentsClient.Test do
  use Plug.Test
  use ExUnit.Case

  alias PipelinesAPI.DeploymentsClient
  alias PipelinesAPI.SecretClient

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @default_project_id "92be1234-1234-4234-8234-123456789012"

  setup do
    Support.Stubs.DB.reset()

    Support.Stubs.Feature.seed()
    Support.Stubs.RBAC.seed_data()
    Support.Stubs.build_shared_factories()

    on_exit(fn ->
      Support.Stubs.reset()
    end)

    {:ok,
     extra_args: %{
       "organization_id" => @default_org_id,
       "project_id" => @default_project_id,
       "requester_id" => UUID.uuid4()
     }}
  end

  describe "DeploymentsClient.list/1" do
    setup [:setup_three_targets]

    test "request list of deployment targets and get :ok response", ctx do
      assert {:ok, targets} =
               DeploymentsClient.list(%{
                 "project_id" => ctx.extra_args["project_id"]
               })

      assert length(targets) == 3
    end
  end

  describe "DeploymentsClient.create/1" do
    setup [:setup_target_params, :setup_secret_params]

    test "when params are valid then creates a new target", ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      target_name = target_params["name"]
      {:ok, key} = SecretClient.key()
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(target_params, UUID.uuid4(), env_vars, files, key)

      assert {:ok, %{id: target_id, name: ^target_name}} = DeploymentsClient.create(params, conn)

      described = PipelinesAPI.SecretClient.describe(%{"target_id" => target_id}, conn)

      expected = %{
        env_vars: [%{name: "VAR", value: "VALUE"}],
        files: [%{path: "FILE", content: Base.encode64("CONTENT")}]
      }

      assert {:ok, ^expected} = described
    end

    test "when params are valid but subject rules have role id not supported it returns error",
         ctx do
      conn = create_conn(ctx)

      target_params =
        Map.merge(ctx.target_params, ctx.extra_args)
        |> Map.put("subject_rules", [
          %{"type" => "ROLE", "subject_id" => "not-supported"}
        ])

      {:ok, key} = SecretClient.key()
      params = create_params(target_params, UUID.uuid4(), [], [], key)

      assert {:error, {:user, "role \"not-supported\" is not valid"}} =
               DeploymentsClient.create(params, conn)
    end

    test "when params are valid but subject rules have user id not supported it returns error",
         ctx do
      conn = create_conn(ctx)
      user_id = "fake-user-id"
      project_id = ctx.extra_args["project_id"]
      org_id = ctx.extra_args["organization_id"]

      target_params =
        Map.merge(ctx.target_params, ctx.extra_args)
        |> Map.put("subject_rules", [
          %{"type" => "USER", "subject_id" => user_id}
        ])

      {:ok, key} = SecretClient.key()
      params = create_params(target_params, UUID.uuid4(), [], [], key)

      expected_message =
        "user \"" <>
          user_id <>
          "\" can't be added to subject rules for project \"" <>
          project_id <> "\" and organization \"" <> org_id <> "\""

      assert {:error, {:user, ^expected_message}} = DeploymentsClient.create(params, conn)
    end

    test "when params are valid but subject rules have user id and roles which are supported it creates target",
         ctx do
      conn = create_conn(ctx)

      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      target_params =
        Map.merge(ctx.target_params, ctx.extra_args)
        |> Map.put("subject_rules", [
          %{"type" => "USER", "subject_id" => subject_id},
          %{"type" => "ROLE", "subject_id" => "admin"}
        ])

      {:ok, key} = SecretClient.key()
      params = create_params(target_params, UUID.uuid4(), [], [], key)

      assert {:ok,
              %{
                active: true,
                description: "Staging environment",
                name: "Staging",
                organization_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
                project_id: "92be1234-1234-4234-8234-123456789012",
                subject_rules: [
                  %{git_login: "milica-nerlovic", subject_id: ^subject_id, type: :USER},
                  %{subject_id: "Admin", type: :ROLE}
                ],
                url: "https://staging.rtx.com"
              }} = DeploymentsClient.create(params, conn)
    end

    test "when params are valid but subject rules have user provider login which is valid it creates target",
         ctx do
      Support.Stubs.build_shared_factories()

      conn = create_conn(ctx)

      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      target_params =
        Map.merge(ctx.target_params, ctx.extra_args)
        |> Map.put("subject_rules", [
          %{"type" => "USER", "git_login" => "milica-nerlovic"}
        ])

      {:ok, key} = SecretClient.key()
      params = create_params(target_params, UUID.uuid4(), [], [], key)

      assert {:ok,
              %{
                active: true,
                description: "Staging environment",
                name: "Staging",
                organization_id: "92be62c2-9cf4-4dad-b168-d6efa6aa5e21",
                project_id: "92be1234-1234-4234-8234-123456789012",
                subject_rules: [
                  %{git_login: "milica-nerlovic", subject_id: ^subject_id, type: :USER}
                ],
                url: "https://staging.rtx.com"
              }} = DeploymentsClient.create(params, conn)
    end

    test "when params are valid but subject rules have user provider login which is not valid it returns error",
         ctx do
      Support.Stubs.build_shared_factories()

      conn = create_conn(ctx)

      target_params =
        Map.merge(ctx.target_params, ctx.extra_args)
        |> Map.put("subject_rules", [
          %{"type" => "USER", "git_login" => "milica-nerlovic-2"}
        ])

      {:ok, key} = SecretClient.key()
      params = create_params(target_params, UUID.uuid4(), [], [], key)

      assert {:error, {:user, "handle milica-nerlovic-2 can't be used as subject id"}} =
               DeploymentsClient.create(params, conn)
    end
  end

  describe "DeploymentsClient.update/1" do
    setup [:setup_target_params, :setup_secret_params]

    test "when params are valid then updates a new target", ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      target_name = target_params["name"]
      {:ok, key} = SecretClient.key()
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(target_params, UUID.uuid4(), env_vars, files, key)
      {:ok, target} = DeploymentsClient.create(params, conn)

      target_params = Map.put(target_params, "id", target.id)

      params =
        params
        |> Map.merge(target_params)
        |> Map.put("env_vars", [%{"name" => "VAR", "value" => "CHANGED"}])
        |> Map.put("files", [%{"path" => "FILE", "content" => "CONTENT CHANGED"}])
        |> Map.put("target_id", target.id)
        |> Map.put("unique_token", UUID.uuid4())
        |> Map.put("old_target", target)
        |> Map.put("old_env_vars", env_vars)
        |> Map.put("old_files", files)

      conn = update_conn(ctx)
      conn = Map.put(conn, :params, params)
      assert {:ok, %{id: target_id, name: ^target_name}} = DeploymentsClient.update(params, conn)

      {:ok, described} = PipelinesAPI.SecretClient.describe(%{"target_id" => target_id}, conn)

      assert params["files"] |> Enum.at(0) |> Map.get("content") ==
               described.files |> Enum.at(0) |> Map.get(:content)
    end

    test "when params are valid but subject rules has role which is not supported then returns error",
         ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()
      params = create_params(target_params, UUID.uuid4(), [], [], key)
      {:ok, target} = DeploymentsClient.create(params, conn)

      target_params = Map.put(target_params, "id", target.id)

      params =
        params
        |> Map.merge(target_params)
        |> Map.put("subject_rules", [%{"type" => "ROLE", "subject_id" => "not-supported"}])
        |> Map.put("unique_token", UUID.uuid4())
        |> Map.put("old_target", target)
        |> Map.put("old_env_vars", [])
        |> Map.put("old_files", [])

      conn = update_conn(ctx)
      conn = Map.put(conn, :params, params)

      assert {:error, {:user, "role \"not-supported\" is not valid"}} =
               DeploymentsClient.update(params, conn)
    end

    test "when params are valid but subject rules has user with subject id which is not supported then returns error",
         ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()
      params = create_params(target_params, UUID.uuid4(), [], [], key)
      {:ok, target} = DeploymentsClient.create(params, conn)

      target_params = Map.put(target_params, "id", target.id)

      user_id = "not_supported"

      params =
        params
        |> Map.merge(target_params)
        |> Map.put("subject_rules", [%{"type" => "USER", "subject_id" => user_id}])
        |> Map.put("unique_token", UUID.uuid4())
        |> Map.put("old_target", target)
        |> Map.put("old_env_vars", [])
        |> Map.put("old_files", [])

      conn = update_conn(ctx) |> Map.put(:params, params)

      expected_message =
        "user \"" <>
          user_id <>
          "\" can't be added to subject rules for project \"" <>
          ctx.extra_args["project_id"] <>
          "\" and organization \"" <> ctx.extra_args["organization_id"] <> "\""

      assert {:error, {:user, ^expected_message}} = DeploymentsClient.update(params, conn)
    end

    test "when params are valid and subject rules has user and role with subject id which are not supported it updates a target",
         ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()
      params = create_params(target_params, UUID.uuid4(), [], [], key)
      {:ok, target} = DeploymentsClient.create(params, conn)

      target_params = Map.put(target_params, "id", target.id)

      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      params =
        params
        |> Map.merge(target_params)
        |> Map.put("subject_rules", [
          %{"type" => "USER", "subject_id" => subject_id},
          %{"type" => "ROLE", "subject_id" => "admin"}
        ])
        |> Map.put("unique_token", UUID.uuid4())
        |> Map.put("old_target", target)
        |> Map.put("old_env_vars", [])
        |> Map.put("old_files", [])

      conn = update_conn(ctx) |> Map.put(:params, params)

      assert {:ok,
              %{
                subject_rules: [
                  %{git_login: "milica-nerlovic", subject_id: ^subject_id, type: :USER},
                  %{subject_id: "Admin", type: :ROLE}
                ]
              }} = DeploymentsClient.update(params, conn)
    end
  end

  describe "DeploymentsClient.delete/1" do
    setup [:setup_target_params, :setup_secret_params]

    test "when params are valid then deletes a new target", ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(target_params, UUID.uuid4(), env_vars, files, key)
      {:ok, target} = DeploymentsClient.create(params, conn)

      {:ok, deleted} =
        DeploymentsClient.delete(
          %{
            "target_id" => target.id,
            "requester_id" => params["requester_id"],
            "unique_token" => params["unique_token"]
          },
          conn
        )

      assert deleted.target_id == target.id
    end

    test "when params are invalid then it doesn't delete a target but doesn't report error",
         ctx do
      conn = create_conn(ctx)
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      {:ok, key} = SecretClient.key()
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]
      params = create_params(target_params, UUID.uuid4(), env_vars, files, key)
      assert {:ok, _} = DeploymentsClient.create(params, conn)

      deleted_id = "00000000-0000-4000-8000-000000000000"

      assert {:ok, deleted} =
               DeploymentsClient.delete(
                 %{
                   "target_id" => deleted_id,
                   "requester_id" => params["requester_id"],
                   "unique_token" => params["unique_token"]
                 },
                 conn
               )

      assert deleted.target_id == deleted_id
    end
  end

  describe "DeploymentsClient.describe/1" do
    setup [:setup_three_targets]

    test "when params are valid and target exists it describes a target", ctx do
      targetName = "target#{1}"

      params = %{
        "target_name" => targetName,
        "project_id" => ctx.extra_args["project_id"]
      }

      {:ok, response} = DeploymentsClient.describe(params)
      assert response.name == targetName
      assert response.project_id == ctx.extra_args["project_id"]
    end

    test "when params are valid and target doesn't exist it returns an error", ctx do
      targetName = "fakeName"

      params = %{
        "target_name" => targetName,
        "project_id" => ctx.extra_args["project_id"]
      }

      assert {:error, response} = DeploymentsClient.describe(params)
      assert {:not_found, "Target not found"} = response
    end
  end

  describe "DeploymentsClient.history/1" do
    setup [:setup_deployment_target, :setup_common_args]

    test "when params are valid and target exists it describes a target", ctx do
      ctx
      |> add_pipeline_promotion("Production", :STARTED, :passed)
      |> add_pipeline_promotion("Production", :STARTED, :failed)
      |> add_pipeline_promotion("Production", :FAILED, :failed)
      |> add_pipeline_promotion("Production", :PENDING, nil)

      params = %{
        "target_id" => ctx.target_id
      }

      assert {:ok, %{deployments: deployments, cursor_before: 0, cursor_after: 0}} =
               DeploymentsClient.history(params)

      assert ["PENDING", "FAILED", "STARTED", "STARTED"] = Enum.map(deployments, & &1.state)
      assert Enum.all?(deployments, &(&1.target_id == ctx.target_id))
    end

    test "when target_id is valid and has no deployments then returns empty list", ctx do
      assert {:ok, %{deployments: [], cursor_before: 0, cursor_after: 0}} =
               DeploymentsClient.history(%{"target_id" => ctx.target_id})
    end

    test "when target_id is invalid then returns error", _ctx do
      assert {:error, {:not_found, "Target not found"}} =
               DeploymentsClient.history(%{"target_id" => UUID.uuid4()})
    end

    test "when target_id is empty then returns error", _ctx do
      assert {:error, {:user, "target_id must be a valid UUID"}} =
               DeploymentsClient.history(%{"target_id" => ""})
    end
  end

  describe "Targets.describe/1" do
    setup [:setup_deployment_target]

    test "when target_id is valid then returns non-empty list", ctx do
      assert {:ok, target} = DeploymentsClient.describe(%{"target_id" => ctx.target_id})

      expected_args = %{
        id: ctx.target_id,
        organization_id: ctx.extra_args["organization_id"],
        project_id: ctx.extra_args["project_id"]
      }

      assert ^expected_args = Map.take(target, ~w(id organization_id project_id)a)
    end

    test "when target_id is invalid then returns error", _ctx do
      assert {:error, {:not_found, "Target not found"}} =
               DeploymentsClient.describe(%{"target_id" => UUID.uuid4()})
    end

    test "when target_id is empty then returns error", _ctx do
      assert {:error,
              {:user,
               "target_name and project_id or target_id is required to describe a deployment target"}} =
               DeploymentsClient.describe(%{})
    end
  end

  describe "Deployments.cordon/2" do
    setup [:setup_deployment_target]

    test "when params are valid and state is on then cordons a target",
         _ctx = %{target_id: target_id} do
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      target = %{target | api_model: %{target.api_model | cordoned: false}}
      Support.Stubs.DB.upsert(:deployment_targets, target)

      params = %{
        "target_id" => target_id,
        "cordoned" => true
      }

      assert {:ok, %{target_id: target_id}} = DeploymentsClient.cordon(params)

      assert %{api_model: %{cordoned: true}} =
               Support.Stubs.DB.find(:deployment_targets, target_id)
    end

    test "when params are valid and state is off then uncordons a target",
         _ctx = %{target_id: target_id} do
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      target = %{target | api_model: %{target.api_model | cordoned: true}}
      Support.Stubs.DB.upsert(:deployment_targets, target)

      params = %{
        "target_id" => target_id,
        "cordoned" => "false"
      }

      assert {:ok, %{target_id: target_id}} = DeploymentsClient.cordon(params)

      assert %{api_model: %{cordoned: false}} =
               Support.Stubs.DB.find(:deployment_targets, target_id)
    end

    test "when target doesn't exist then returns error", _ctx do
      params = %{
        "target_id" => UUID.uuid4(),
        "cordoned" => true
      }

      {:error, {:not_found, "Target not found"}} = DeploymentsClient.cordon(params)

      params = %{
        "target_id" => UUID.uuid4(),
        "cordoned" => "False"
      }

      {:error, {:not_found, "Target not found"}} = DeploymentsClient.cordon(params)
    end

    test "when params are invalid then returns error", _ctx do
      assert {:error, {:user, "target_id is required to activate/deactivate a deployment target"}} =
               DeploymentsClient.cordon(%{"cordoned" => "true"})

      assert {:error, {:user, "target_id is required to activate/deactivate a deployment target"}} =
               DeploymentsClient.cordon(%{"cordoned" => "false"})
    end

    test "when target is in invalid state then returns error", _ctx = %{target_id: target_id} do
      Support.Stubs.Deployments.Grpc.expect(:cordon, 2, fn ->
        raise GRPC.RPCError, status: :failed_precondition, message: "Invalid state: SYNCING"
      end)

      params = %{
        "target_id" => target_id,
        "cordoned" => true
      }

      {:error, {:user, "Invalid state: SYNCING"}} = DeploymentsClient.cordon(params)

      params = %{
        "target_id" => target_id,
        "cordoned" => false
      }

      {:error, {:user, "Invalid state: SYNCING"}} = DeploymentsClient.cordon(params)

      GrpcMock.verify!(DeploymentsMock)
    end
  end

  defp create_params(target_params, unique_token, env_vars, files, key) do
    target_params
    |> Map.merge(%{
      "requester_id" => target_params["requester_id"],
      "env_vars" => env_vars,
      "files" => files,
      "key" => key,
      "unique_token" => unique_token
    })
  end

  defp setup_three_targets(ctx) do
    project = %{org_id: ctx.extra_args["organization_id"], id: ctx.extra_args["project_id"]}
    user = %{id: ctx.extra_args["requester_id"]}

    for i <- 1..3 do
      Support.Stubs.Deployments.create(project, user, "target#{i}")
    end

    {:ok, project_id: project.id}
  end

  defp setup_target_params(ctx) do
    {:ok,
     target_params: %{
       "id" => UUID.uuid4(),
       "name" => "Staging",
       "description" => "Staging environment",
       "url" => "https://staging.rtx.com",
       "object_rules" => [
         %{"type" => "BRANCH", "match_mode" => "EXACT", "pattern" => "main"},
         %{"type" => "PR", "match_mode" => "ALL", "pattern" => ""}
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

  defp setup_common_args(_ctx) do
    org = Support.Stubs.Organization.create_default()
    user = Support.Stubs.User.create_default()
    project = Support.Stubs.Project.create(org, user, name: "test_project")
    branch = Support.Stubs.Branch.create(project)
    hook = Support.Stubs.Hook.create(branch)
    workflow = Support.Stubs.Workflow.create(hook, user)

    pipeline =
      Support.Stubs.Pipeline.create(workflow,
        name: "Pipeline",
        commit_message: hook.api_model.commit_message
      )
      |> then(&Support.Stubs.Pipeline.change_state(&1.id, :passed))

    switch = Support.Stubs.Pipeline.add_switch(pipeline)

    {:ok,
     org: org,
     user: user,
     project: project,
     hook: hook,
     workflow: workflow,
     pipeline: pipeline,
     switch: switch}
  end

  defp add_pipeline_promotion(
         ctx,
         target_name,
         deployment_state,
         pipeline_state
       ) do
    target =
      if deployment_state == :STARTED do
        pipeline =
          Support.Stubs.Pipeline.create(ctx.workflow,
            name: "Deploy to #{target_name}",
            promotion_of: ctx.pipeline.id,
            commit_message: ctx.hook.api_model.commit_message
          )
          |> then(&Support.Stubs.Pipeline.change_state(&1.id, pipeline_state))

        Support.Stubs.Deployments.add_deployment(ctx.target, ctx.user, ctx.switch, %{
          pipeline_id: pipeline.id,
          state: deployment_state
        })
      else
        Support.Stubs.Deployments.add_deployment(ctx.target, ctx.user, ctx.switch, %{
          state: deployment_state
        })
      end

    Map.put(ctx, :target, target)
  end

  defp create_conn(ctx) do
    init_conn()
    |> put_req_header("x-semaphore-user-id", ctx.extra_args["requester_id"])
    |> put_req_header("x-semaphore-org-id", ctx.extra_args["organization_id"])
  end

  defp update_conn(ctx) do
    conn(:patch, "/deployments")
    |> put_req_header("x-semaphore-user-id", ctx.extra_args["requester_id"])
    |> put_req_header("x-semaphore-org-id", ctx.extra_args["organization_id"])
  end

  defp init_conn() do
    conn(:post, "/deployments")
  end
end
