defmodule Front.Models.DeploymentsTest do
  use ExUnit.Case, async: false
  @moduletag capture_log: true
  @moduletag :deployments

  alias Front.Models.Deployments
  alias Front.Models.Deployments.Secrets
  alias Front.Models.Deployments.Targets
  alias Front.Models.DeploymentsError
  alias Front.Models.DeploymentTarget, as: Target
  alias Support.Stubs.Deployments, as: DeploymentsStub
  alias Support.Stubs.Secret.Keys, as: StubKeys

  setup do
    on_exit(fn ->
      Support.Stubs.init()
    end)

    {:ok,
     extra_args: %{
       organization_id: UUID.uuid4(),
       project_id: UUID.uuid4(),
       requester_id: UUID.uuid4()
     }}
  end

  describe "Secrets.get_key/0" do
    test "when key is valid then returns it" do
      %{key_id: id, public_key: key} = StubKeys.get_key()
      assert {:ok, {^id, ^key}} = Secrets.get_key()
    end

    test "when key is corrupted then returns error" do
      setup_corrupted_key()

      assert {:error, %GRPC.RPCError{}} = Secrets.get_key()
    end
  end

  describe "Secrets.encrypt_data/1" do
    test "when key is valid then encrypts data" do
      secret_data = %{
        env_vars: [%{name: "ENV_VAR", value: "VALUE"}],
        files: [%{path: "PATH", content: "CONTENT"}]
      }

      assert {:ok, encrypted_data} = Secrets.encrypt_data(secret_data)
      assert {:ok, decrypted_data} = StubKeys.decrypt(encrypted_data)
      assert ^secret_data = Util.Proto.to_map!(decrypted_data)
    end

    test "when key is invalid then returns error" do
      setup_invalid_key()

      secret_data = %{
        env_vars: [%{name: "ENV_VAR", value: "VALUE"}],
        files: [%{path: "PATH", content: "CONTENT"}]
      }

      assert {:error, %DeploymentsError{message: "Invalid public key"}} =
               Secrets.encrypt_data(secret_data)
    end

    test "when key is corrupted then returns error" do
      setup_corrupted_key()

      secret_data = %{
        env_vars: [%{name: "ENV_VAR", value: "VALUE"}],
        files: [%{path: "PATH", content: "CONTENT"}]
      }

      assert {:error, %DeploymentsError{message: "Cannot fetch key"}} =
               Secrets.encrypt_data(secret_data)
    end
  end

  describe "Secrets.describe/2" do
    setup [:setup_deployment_target]

    test "when target_id is valid then returns secret", ctx do
      assert {:ok, %{env_vars: env_vars, files: files}} =
               Secrets.describe_data(ctx.target_id, ctx.extra_args)

      assert [%{name: "VAR", value: "VALUE"}] = env_vars
      assert [%{path: "FILE", content: "CONTENT"}] = files
    end

    test "when target_id is invalid then returns empty data", ctx do
      assert {:ok, %{env_vars: [], files: []}} =
               Secrets.describe_data(UUID.uuid4(), ctx.extra_args)
    end

    test "when target_id is empty then returns error", ctx do
      assert {:error, %GRPC.RPCError{status: 9, message: "Missing lookup argument"}} =
               Secrets.describe_data("", ctx.extra_args)
    end
  end

  describe "Targets.list/1" do
    setup [:setup_three_targets]

    test "when project_id is valid then returns non-empty list", ctx do
      assert {:ok, targets} = Targets.list(ctx.project_id)
      assert MapSet.new(for i <- 1..3, do: "target#{i}") == MapSet.new(targets, & &1.name)
    end

    test "when project_id is invalid then returns empty list", _ctx do
      assert {:ok, []} = Targets.list(UUID.uuid4())
    end

    test "when project_id is empty then returns error", _ctx do
      assert {:error, %GRPC.RPCError{status: 3, message: "Missing argument: project_id"}} =
               Targets.list("")
    end
  end

  describe "Targets.describe/1" do
    setup [:setup_deployment_target]

    test "when target_id is valid then returns non-empty list", ctx do
      expected_args = ctx.extra_args |> Map.delete(:requester_id) |> Map.put(:id, ctx.target_id)
      assert {:ok, target} = Targets.describe(ctx.target_id)
      assert ^expected_args = Map.take(target, ~w(id organization_id project_id)a)
    end

    test "when target_id is invalid then returns error", _ctx do
      assert {:error, %GRPC.RPCError{status: 5, message: "Target not found"}} =
               Targets.describe(UUID.uuid4())
    end

    test "when target_id is empty then returns error", _ctx do
      message = "Missing arguments: target_id or (project_id, target_name)"

      assert {:error, %GRPC.RPCError{status: 3, message: ^message}} = Targets.describe("")
    end
  end

  describe "Deployments.fetch_targets/2" do
    setup [:setup_three_targets]

    test "when HIDE_PROMOTIONS flag is not set it returns a valid reponse ", ctx do
      assert {:ok, targets} = Deployments.fetch_targets(ctx.project_id)
      assert MapSet.new(for i <- 1..3, do: "target#{i}") == MapSet.new(targets, & &1.name)
    end

    test "when HIDE_PROMOTIONS flag is set to true, returns an empty list", ctx do
      Application.put_env(:front, :hide_promotions, true)
      on_exit(fn -> Application.put_env(:front, :hide_promotions, false) end)

      assert {:ok, []} == Deployments.fetch_targets(ctx.project_id)
    end
  end

  describe "Deployments.fetch_history/2" do
    setup [:setup_deployment_target, :setup_common_args]

    test "when target_id is valid and has deployments then returns their list", ctx do
      ctx
      |> add_pipeline_promotion("Production", :STARTED, :passed)
      |> add_pipeline_promotion("Production", :STARTED, :failed)
      |> add_pipeline_promotion("Production", :FAILED, :failed)
      |> add_pipeline_promotion("Production", :PENDING, nil)

      assert {:ok, %{deployments: deployments, cursor_before: 0, cursor_after: 0}} =
               Deployments.fetch_history(ctx.target_id)

      assert [:PENDING, :FAILED, :STARTED, :STARTED] = Enum.map(deployments, & &1.state)
      assert Enum.all?(deployments, &(&1.target_id == ctx.target_id))
    end

    test "when target_id is valid and has no deployments then returns empty list", ctx do
      assert {:ok, %{deployments: [], cursor_before: 0, cursor_after: 0}} =
               Deployments.fetch_history(ctx.target_id)
    end

    test "when target_id is invalid then returns error", _ctx do
      assert {:error, %GRPC.RPCError{status: 5, message: "Target not found"}} =
               Deployments.fetch_history(UUID.uuid4())
    end

    test "when target_id is empty then returns error", _ctx do
      message = "Missing argument: target_id"

      assert {:error, %GRPC.RPCError{status: 3, message: ^message}} =
               Deployments.fetch_history("")
    end
  end

  describe "Targets.create/2" do
    setup [:setup_target_params, :setup_secret_params]

    test "when params are valid then creates a new target", ctx do
      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      secret_params = Map.merge(ctx.secret_params, ctx.extra_args)

      assert {:ok, %{id: target_id, name: "Staging"}} =
               Targets.create(target_params, secret_params, UUID.uuid4(), UUID.uuid4())

      assert {:ok,
              %{
                env_vars: [%{name: "VAR", value: "VALUE"}],
                files: [%{path: "FILE", content: "CONTENT"}]
              }} = Secrets.describe_data(target_id, %{})
    end

    test "when params are invalid then returns error", ctx do
      target_params = ctx.target_params |> Map.merge(ctx.extra_args) |> Map.delete(:name)
      secret_params = Map.merge(ctx.secret_params, ctx.extra_args)

      assert {:error, %GRPC.RPCError{status: 3, message: "Changeset error"}} =
               Targets.create(target_params, secret_params, UUID.uuid4(), UUID.uuid4())
    end

    test "when unknown error has occured then returns error", ctx do
      DeploymentsStub.Grpc.expect(:create, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unable to create DT secret"
      end)

      target_params = Map.merge(ctx.target_params, ctx.extra_args)
      secret_params = Map.merge(ctx.secret_params, ctx.extra_args)

      assert {:error, %GRPC.RPCError{status: 13, message: "Unable to create DT secret"}} =
               Targets.create(target_params, secret_params, UUID.uuid4(), UUID.uuid4())

      GrpcMock.verify!(DeploymentsMock)
    end
  end

  describe "Targets.update/4" do
    setup [:setup_deployment_target, :setup_target_params, :setup_secret_params]

    test "when params are valid then updates a target", ctx do
      target_params =
        ctx.target_params
        |> Map.put(:id, ctx.target_id)
        |> Map.merge(ctx.extra_args)

      secret_params = Map.merge(ctx.secret_params, ctx.extra_args)

      assert {:ok, %{id: target_id, name: "Staging"}} =
               Targets.update(target_params, secret_params, UUID.uuid4(), UUID.uuid4())

      assert {:ok,
              %{
                env_vars: [%{name: "VAR", value: "VALUE"}],
                files: [%{path: "FILE", content: "CONTENT"}]
              }} = Secrets.describe_data(target_id, %{})
    end

    test "when params are invalid then returns error", ctx do
      target_params =
        ctx.target_params
        |> Map.put(:id, ctx.target_id)
        |> Map.merge(ctx.extra_args)
        |> Map.delete(:name)

      secret_params = Map.merge(ctx.secret_params, ctx.extra_args)

      assert {:error, %GRPC.RPCError{status: 3, message: "Changeset error"}} =
               Targets.update(target_params, secret_params, UUID.uuid4(), UUID.uuid4())
    end

    test "when unknown error has occured then returns error", ctx do
      DeploymentsStub.Grpc.expect(:update, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unable to edit DT secret"
      end)

      target_params =
        ctx.target_params
        |> Map.put(:id, ctx.target_id)
        |> Map.merge(ctx.extra_args)

      secret_params = Map.merge(ctx.secret_params, ctx.extra_args)

      assert {:error, %GRPC.RPCError{status: 13, message: "Unable to edit DT secret"}} =
               Targets.update(target_params, secret_params, UUID.uuid4(), UUID.uuid4())

      GrpcMock.verify!(DeploymentsMock)
    end

    test "when target is in invalid state then returns error", ctx do
      DeploymentsStub.Grpc.expect(:update, fn ->
        raise GRPC.RPCError, status: :failed_precondition, message: "Invalid state: SYNCING"
      end)

      target_params =
        ctx.target_params
        |> Map.put(:id, ctx.target_id)
        |> Map.merge(ctx.extra_args)

      secret_params = Map.merge(ctx.secret_params, ctx.extra_args)

      assert {:error, %GRPC.RPCError{status: 9, message: "Invalid state: SYNCING"}} =
               Targets.update(target_params, secret_params, UUID.uuid4(), UUID.uuid4())

      GrpcMock.verify!(DeploymentsMock)
    end
  end

  describe "Targets.delete/2" do
    setup [:setup_deployment_target]

    test "when params are valid then deletes a target",
         ctx = %{target_id: target_id, secret_id: secret_id} do
      assert {:ok, ^target_id} =
               Targets.delete(ctx.target_id, UUID.uuid4(), ctx.extra_args.requester_id)

      refute Support.Stubs.DB.find(:deployment_targets, target_id)
      refute Support.Stubs.DB.find(:deployment_secrets, secret_id)
    end

    test "when target doesn't exist then returns its ID", _ctx do
      target_id = UUID.uuid4()
      assert {:ok, ^target_id} = Targets.delete(target_id, UUID.uuid4(), UUID.uuid4())
    end

    test "when params are invalid then returns error", _ctx do
      assert {:error, %GRPC.RPCError{status: 3, message: "Missing argument: target_id"}} =
               Targets.delete("", UUID.uuid4(), UUID.uuid4())

      assert {:error, %GRPC.RPCError{status: 3, message: "Missing argument: unique_token"}} =
               Targets.delete(UUID.uuid4(), "", UUID.uuid4())

      assert {:error, %GRPC.RPCError{status: 3, message: "Missing argument: requester_id"}} =
               Targets.delete(UUID.uuid4(), UUID.uuid4(), "")
    end

    test "when target is in invalid state then returns error", ctx do
      DeploymentsStub.Grpc.expect(:delete, fn ->
        raise GRPC.RPCError, status: :failed_precondition, message: "Invalid state: SYNCING"
      end)

      assert {:error, %GRPC.RPCError{status: 9, message: "Invalid state: SYNCING"}} =
               Targets.delete(ctx.target_id, UUID.uuid4(), ctx.extra_args.requester_id)

      GrpcMock.verify!(DeploymentsMock)
    end
  end

  describe "Deployments.create/2" do
    setup [:setup_params]

    test "when model is valid then creates a new target", ctx do
      assert {:ok, target = %{id: target_id, name: "Production"}} =
               Deployments.create(ctx.params, ctx.extra_args)

      assert target.state == :USABLE
      assert target.state_message == ""
      assert target.created_by == ctx.extra_args.requester_id
      assert target.updated_by == ctx.extra_args.requester_id

      assert Enum.count(target.subject_rules) == 4
      assert Enum.count(target.object_rules) == 5

      assert {:ok, secret_data} = Deployments.fetch_secret_data(target_id, [])
      assert Enum.count(secret_data.env_vars) == 2
      assert Enum.count(secret_data.files) == 2
    end

    test "when secret has not changed then doesn't create secret", ctx do
      params = %{ctx.params | "env_vars" => [], "files" => []}

      assert {:ok, _target = %{id: target_id, name: "Production"}} =
               Deployments.create(params, ctx.extra_args)

      refute Support.Stubs.DB.find_by(:deployment_secrets, :dt_id, target_id)
    end

    test "when model is invalid then returns error", ctx do
      assert {:error, %Ecto.Changeset{valid?: false, errors: [name: {"can't be blank", _}]}} =
               Deployments.create(%{ctx.params | "name" => ""}, ctx.extra_args)
    end

    test "when secret encryption fails then returns error", ctx do
      setup_corrupted_key()

      assert {:error, %DeploymentsError{message: "Cannot fetch key"}} =
               Deployments.create(ctx.params, ctx.extra_args)
    end

    test "when unknown error has occured then returns error", ctx do
      DeploymentsStub.Grpc.expect(:create, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unable to create DT secret"
      end)

      assert {:error, %GRPC.RPCError{status: 13, message: "Unable to create DT secret"}} =
               Deployments.create(ctx.params, ctx.extra_args)

      GrpcMock.verify!(DeploymentsMock)
    end
  end

  describe "Deployments.update/4" do
    setup [:setup_deployment_target, :setup_params]

    test "when params are valid then updates a target", ctx = %{target_id: target_id} do
      model = Target.from_api(ctx.target.api_model, ctx.secret.api_model.data)
      secret_data = ctx.secret.api_model.data

      assert {:ok, target = %{id: ^target_id, name: "Production"}} =
               Deployments.update(model, ctx.params, secret_data, ctx.extra_args)

      assert target.state == :USABLE
      assert target.state_message == ""
      assert target.created_by == ctx.extra_args.requester_id
      assert target.updated_by == ctx.extra_args.requester_id

      assert Enum.count(target.subject_rules) == 4
      assert Enum.count(target.object_rules) == 5

      assert {:ok, secret_data} = Deployments.fetch_secret_data(target_id, [])
      assert Enum.count(secret_data.env_vars) == 2
      assert Enum.count(secret_data.files) == 2
    end

    test "when secret has not changed then doesn't update secret",
         ctx = %{target_id: target_id} do
      model = Target.from_api(ctx.target.api_model, ctx.secret.api_model.data)
      secret_data = ctx.secret.api_model.data

      params = %{
        ctx.params
        | "env_vars" =>
            Enum.map(
              secret_data.env_vars,
              &%{
                "id" => &1.name,
                "name" => &1.name,
                "value" => "",
                "md5" => md5_checksum(&1.value)
              }
            ),
          "files" =>
            Enum.map(
              secret_data.files,
              &%{
                "id" => &1.path,
                "path" => &1.path,
                "content" => "",
                "md5" => md5_checksum(&1.content)
              }
            )
      }

      assert {:ok, target = %{id: ^target_id, name: "Production"}} =
               Deployments.update(model, params, secret_data, ctx.extra_args)

      assert secret = Support.Stubs.DB.find_by(:deployment_secrets, :dt_id, target_id)
      assert Enum.count(secret.api_model.data.env_vars) == 1
      assert Enum.count(secret.api_model.data.files) == 1

      assert secret.api_model.metadata.updated_at.seconds <
               target.updated_at.seconds
    end

    test "when params are invalid then returns error", ctx do
      model = Target.from_api(ctx.target.api_model, ctx.secret.api_model.data)
      secret_data = ctx.secret.api_model.data
      params = %{ctx.params | "name" => ""}

      assert {:error, %Ecto.Changeset{valid?: false, errors: [name: {"can't be blank", _}]}} =
               Deployments.update(model, params, secret_data, ctx.extra_args)
    end

    test "when secret was modified then returns error", ctx do
      model = Target.from_api(ctx.target.api_model, ctx.secret.api_model.data)
      secret_data = %{env_vars: [], files: []}

      params = %{
        ctx.params
        | "env_vars" =>
            Support.Factories.Deployments.wrap_env_vars([
              %{"id" => "ENV_VAR", "name" => "EV1", "value" => "", "md5" => "md5"},
              %{"name" => "EV2", "value" => "VALUE_2"}
            ]),
          "files" =>
            Support.Factories.Deployments.wrap_files([
              %{"id" => "FILE", "path" => "F1", "content" => "", "md5" => "md5"},
              %{"path" => "F2", "content" => "CONTENT_2"}
            ])
      }

      assert {:error, %DeploymentsError{message: "Secret was modified in the meantime"}} =
               Deployments.update(model, params, secret_data, ctx.extra_args)
    end

    test "when secret encryption fails then returns error", ctx do
      setup_corrupted_key()

      model = Target.from_api(ctx.target.api_model, ctx.secret.api_model.data)
      secret_data = ctx.secret.api_model.data

      assert {:error, %DeploymentsError{message: "Cannot fetch key"}} =
               Deployments.update(model, ctx.params, secret_data, ctx.extra_args)
    end

    test "when unknown error has occured then returns error", ctx do
      DeploymentsStub.Grpc.expect(:update, fn ->
        raise GRPC.RPCError, status: :internal, message: "Unable to create DT secret"
      end)

      model = Target.from_api(ctx.target.api_model, ctx.secret.api_model.data)
      secret_data = ctx.secret.api_model.data

      assert {:error, %GRPC.RPCError{status: 13, message: "Unable to create DT secret"}} =
               Deployments.update(model, ctx.params, secret_data, ctx.extra_args)

      GrpcMock.verify!(DeploymentsMock)
    end
  end

  describe "Deployments.switch_cordon/2" do
    setup [:setup_deployment_target]

    test "when params are valid and state is on then cordons a target",
         ctx = %{target_id: target_id} do
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      target = %{target | api_model: %{target.api_model | cordoned: false}}
      Support.Stubs.DB.upsert(:deployment_targets, target)

      assert {:ok, ^target_id} = Deployments.switch_cordon(ctx.target_id, :on)

      assert %{api_model: %{cordoned: true}} =
               Support.Stubs.DB.find(:deployment_targets, target_id)
    end

    test "when params are valid and state is off then uncordons a target",
         ctx = %{target_id: target_id} do
      target = Support.Stubs.DB.find(:deployment_targets, target_id)
      target = %{target | api_model: %{target.api_model | cordoned: true}}
      Support.Stubs.DB.upsert(:deployment_targets, target)

      assert {:ok, ^target_id} = Deployments.switch_cordon(ctx.target_id, :off)

      assert %{api_model: %{cordoned: false}} =
               Support.Stubs.DB.find(:deployment_targets, target_id)
    end

    test "when target doesn't exist then returns error", _ctx do
      assert {:error, %GRPC.RPCError{status: 5, message: "Target not found"}} =
               Deployments.switch_cordon(UUID.uuid4(), :on)

      assert {:error, %GRPC.RPCError{status: 5, message: "Target not found"}} =
               Deployments.switch_cordon(UUID.uuid4(), :off)
    end

    test "when params are invalid then returns error", _ctx do
      assert {:error, %GRPC.RPCError{status: 3, message: "Missing argument: target_id"}} =
               Deployments.switch_cordon("", :on)

      assert {:error, %GRPC.RPCError{status: 3, message: "Missing argument: target_id"}} =
               Deployments.switch_cordon("", :off)
    end

    test "when target is in invalid state then returns error", ctx do
      DeploymentsStub.Grpc.expect(:cordon, 2, fn ->
        raise GRPC.RPCError, status: :failed_precondition, message: "Invalid state: SYNCING"
      end)

      assert {:error, %GRPC.RPCError{status: 9, message: "Invalid state: SYNCING"}} =
               Deployments.switch_cordon(ctx.target_id, :on)

      assert {:error, %GRPC.RPCError{status: 9, message: "Invalid state: SYNCING"}} =
               Deployments.switch_cordon(ctx.target_id, :off)

      GrpcMock.verify!(DeploymentsMock)
    end
  end

  defp md5_checksum(value),
    do: value |> :erlang.md5() |> Base.encode16(case: :lower)

  defp setup_invalid_key do
    alias InternalApi.Secrethub.GetKeyResponse, as: Response
    GrpcMock.expect(SecretMock, :get_key, Response.new(id: "123456789", key: "foo"))
    on_exit(fn -> Support.Stubs.Secret.Keys.init() end)
  end

  defp setup_corrupted_key do
    previous_key = StubKeys.get_key()
    corrupted_key = %{previous_key | public_key: "foo"}

    Agent.update(StubKeys, fn _ -> corrupted_key end)
    on_exit(fn -> Agent.update(StubKeys, fn _ -> previous_key end) end)
  end

  defp setup_deployment_target(ctx) do
    project = %{org_id: ctx.extra_args.organization_id, id: ctx.extra_args.project_id}
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

  defp setup_three_targets(ctx) do
    project = %{org_id: ctx.extra_args.organization_id, id: ctx.extra_args.project_id}
    user = %{id: ctx.extra_args.requester_id}

    for i <- 1..3, do: Support.Stubs.Deployments.create(project, user, "target#{i}")
    {:ok, project_id: project.id}
  end

  defp setup_params(_ctx) do
    {:ok, params: Support.Factories.Deployments.prepare_params()}
  end

  defp setup_target_params(_ctx) do
    {:ok,
     target_params: %{
       id: UUID.uuid4(),
       name: "Staging",
       description: "Staging environment",
       url: "https://staging.rtx.com",
       subject_rules: [
         %{type: 0, subject_id: UUID.uuid4()},
         %{type: 1, subject_id: UUID.uuid4()}
       ],
       object_rules: [
         %{type: 0, match_mode: 0, pattern: ""},
         %{type: 1, match_mode: 0, pattern: ""}
       ]
     }}
  end

  defp setup_secret_params(_ctx) do
    alias InternalApi.Secrethub.Secret.Data

    {:ok, encrypted_data} =
      StubKeys.encrypt(
        Util.Proto.deep_new!(Data, %{
          env_vars: [%{name: "VAR", value: "VALUE"}],
          files: [%{path: "FILE", content: "CONTENT"}]
        })
      )

    {:ok, secret_params: encrypted_data}
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
end
