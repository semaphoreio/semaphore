defmodule Gofer.Deployment.Model.DeploymentQueriesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch
  alias Gofer.EctoRepo

  setup [
    :truncate_database,
    :init_ids,
    :prepare_encrypted_secret_data,
    :setup_staging_example,
    :setup_canary_example,
    :setup_production_example,
    :setup_switch,
    :setup_deployments,
    :prepare_params
  ]

  describe "list_by_project/2" do
    test "when none are configured then return empty list" do
      non_existent_project_id = UUID.uuid4()
      deployments = DeploymentQueries.list_by_project(non_existent_project_id)
      assert Enum.empty?(deployments)
    end

    test "when some are configured then return list of targets", ctx do
      deployments = DeploymentQueries.list_by_project(ctx[:project_id])
      assert deployments |> MapSet.new(& &1.id) |> MapSet.member?(ctx[:staging].id)
      assert deployments |> MapSet.new(& &1.id) |> MapSet.member?(ctx[:canary].id)
      assert deployments |> MapSet.new(& &1.id) |> MapSet.member?(ctx[:prod].id)
    end
  end

  describe "list_by_project_with_last_triggers/1" do
    test "when target was used to deploy then return list with last deployment",
         ctx do
      deployments = DeploymentQueries.list_by_project_with_last_triggers(ctx[:project_id])
      assert Enum.all?(deployments, &is_map/1)
      assert Enum.count(deployments) == 3

      prod_target = Enum.find(deployments, &(&1.deployment.id == ctx[:prod].id))
      assert prod_target.last_trigger.id == ctx.prod_trigger.id
      assert prod_target.last_trigger.state == ctx.prod_trigger.state
      assert prod_target.last_trigger.result == ctx.prod_trigger.result
      assert %Switch{} = prod_target.switch

      staging_target = Enum.find(deployments, &(&1.deployment.id == ctx[:staging].id))
      assert staging_target.last_trigger.id == ctx.staging_trigger.id
      assert staging_target.last_trigger.state == ctx.staging_trigger.state
      assert is_nil(staging_target.last_trigger.result)
      assert %Switch{} = staging_target.switch

      canary_target = Enum.find(deployments, &(&1.deployment.id == ctx[:canary].id))
      assert is_nil(canary_target.last_trigger)
      assert is_nil(canary_target.switch)
    end
  end

  describe "find_by_id/1" do
    test "when deployment exists then return it", ctx do
      %{staging: staging_dt, canary: canary_dt, prod: prod_dt} = ctx

      assert {:ok, ^staging_dt} = DeploymentQueries.find_by_id(staging_dt.id)
      assert {:ok, ^canary_dt} = DeploymentQueries.find_by_id(canary_dt.id)
      assert {:ok, ^prod_dt} = DeploymentQueries.find_by_id(prod_dt.id)
    end

    test "when deployment doesn't exist then return error" do
      assert {:error, :not_found} = DeploymentQueries.find_by_id(UUID.uuid4())
    end
  end

  describe "find_by_project_and_name/1" do
    test "when deployment exists then return it", ctx do
      %{project_id: project_id, staging: staging_dt, canary: canary_dt, prod: prod_dt} = ctx

      assert {:ok, ^staging_dt} =
               DeploymentQueries.find_by_project_and_name(project_id, staging_dt.name)

      assert {:ok, ^canary_dt} =
               DeploymentQueries.find_by_project_and_name(project_id, canary_dt.name)

      assert {:ok, ^prod_dt} =
               DeploymentQueries.find_by_project_and_name(project_id, prod_dt.name)
    end

    test "when deployment doesn't exist then return error", ctx do
      assert {:error, :not_found} =
               DeploymentQueries.find_by_project_and_name(ctx[:project_id], "nightly")
    end
  end

  describe "find_by_unique_token/1" do
    test "when deployment exists then return it", ctx do
      %{staging: staging_dt, canary: canary_dt, prod: prod_dt} = ctx

      assert {:ok, ^staging_dt} = DeploymentQueries.find_by_unique_token(staging_dt.unique_token)
      assert {:ok, ^canary_dt} = DeploymentQueries.find_by_unique_token(canary_dt.unique_token)
      assert {:ok, ^prod_dt} = DeploymentQueries.find_by_unique_token(prod_dt.unique_token)
    end

    test "when deployment doesn't exist then return error" do
      assert {:error, :not_found} = DeploymentQueries.find_by_unique_token(UUID.uuid4())
    end
  end

  describe "create/1" do
    test "when deployment exists then return error", ctx do
      assert {:error, %Ecto.Changeset{errors: errors}} =
               DeploymentQueries.create(
                 %{ctx[:valid_params] | name: "Production"},
                 ctx[:encrypted_secret_data]
               )

      assert [name: {"has already been taken", [{:constraint, :unique} | _]}] = errors
    end

    test "when invalid parameters are provided then return error", ctx do
      assert {:error, %Ecto.Changeset{errors: errors}} =
               DeploymentQueries.create(ctx[:invalid_params], ctx[:encrypted_secret_data])

      assert [name: {"can't be blank", _}] = errors
    end

    test "when requester ID is not provided then return error", ctx do
      assert {:error, %Ecto.Changeset{errors: errors}} =
               DeploymentQueries.create(ctx[:valid_params], %{
                 unique_token: UUID.uuid4()
               })

      assert [encrypted_secret: {"is invalid", [requester_id: {"can't be blank", _}]}] = errors
    end

    test "when unique_token is not provided then return error", ctx do
      assert {:error, %Ecto.Changeset{errors: errors}} =
               DeploymentQueries.create(ctx[:valid_params], %{
                 requester_id: UUID.uuid4()
               })

      assert [encrypted_secret: {"is invalid", [unique_token: {"can't be blank", _}]}] = errors
    end

    test "when empty payload is provided then return error", ctx do
      for field <- ~w(key_id aes256_key init_vector payload)a do
        params = Map.delete(ctx[:encrypted_secret_data], field)

        assert {:error, %Ecto.Changeset{errors: errors}} =
                 DeploymentQueries.create(ctx[:valid_params], params)

        assert [encrypted_secret: {"is invalid", [{^field, {"can't be blank", _}}]}] = errors
      end
    end

    test "when deployment doesn't exist then return it", ctx do
      params = ctx[:valid_params]
      timestamp = NaiveDateTime.utc_now()

      assert {:ok, deployment = %Deployment{state: :SYNCING}} =
               DeploymentQueries.create(ctx[:valid_params], ctx[:encrypted_secret_data])

      assert deployment.name == params[:name]
      assert NaiveDateTime.diff(deployment.inserted_at, timestamp) >= 0
    end

    test "when deployment doesn't have secret then it's ready immediately", ctx do
      params = ctx[:valid_params]
      timestamp = NaiveDateTime.utc_now()

      assert {:ok, deployment = %Deployment{state: :FINISHED, result: :SUCCESS}} =
               DeploymentQueries.create(ctx[:valid_params], :no_secret_params)

      assert deployment.name == params[:name]
      refute deployment.encrypted_secret
      assert NaiveDateTime.diff(deployment.inserted_at, timestamp) >= 0
    end

    test "when deployment doesn't exist then persist data", ctx do
      params = ctx[:valid_params]

      assert {:ok, deployment = %Deployment{state: :SYNCING}} =
               DeploymentQueries.create(ctx[:valid_params], ctx[:encrypted_secret_data])

      assert deployment.description == params[:description]
      assert deployment.organization_id == params[:organization_id]
      assert deployment.project_id == params[:project_id]

      assert deployment.subject_rules ==
               Enum.map(params[:subject_rules], &struct(Deployment.SubjectRule, &1))

      assert deployment.object_rules ==
               Enum.map(params[:object_rules], &struct(Deployment.ObjectRule, &1))

      assert deployment.bookmark_parameter1 == params[:bookmark_parameter1]
      assert deployment.bookmark_parameter2 == params[:bookmark_parameter2]
      assert deployment.bookmark_parameter3 == params[:bookmark_parameter3]
    end

    test "when unique token is given then runs transaction", ctx do
      assert {:ok, %Deployment{state: :SYNCING}} =
               DeploymentQueries.create(
                 ctx[:encrypted_secret_data][:unique_token],
                 ctx[:valid_params],
                 ctx[:encrypted_secret_data]
               )

      assert {:error, {:already_done, %Deployment{state: :SYNCING}}} =
               DeploymentQueries.create(
                 ctx[:encrypted_secret_data][:unique_token],
                 ctx[:valid_params],
                 ctx[:encrypted_secret_data]
               )

      unique_token = UUID.uuid4()
      secret_data = %{ctx[:encrypted_secret_data] | unique_token: unique_token}

      assert {:error, %Ecto.Changeset{errors: [name: {"has already been taken", _}]}} =
               DeploymentQueries.create(unique_token, ctx[:valid_params], secret_data)
    end
  end

  describe "update/1" do
    test "when deployment is in :SYNCING state then returns error", ctx do
      assert {:error, {:invalid_state, :SYNCING}} =
               DeploymentQueries.update(
                 ctx[:canary],
                 ctx[:valid_params],
                 ctx[:encrypted_secret_data]
               )
    end

    test "when invalid parameters are provided then return error", ctx do
      assert {:error, %Ecto.Changeset{errors: [name: {"can't be blank", _}]}} =
               DeploymentQueries.update(
                 ctx[:staging],
                 ctx[:invalid_params],
                 ctx[:encrypted_secret_data]
               )

      assert {:ok, %Deployment{state: :FINISHED, result: :SUCCESS}} =
               DeploymentQueries.find_by_id(ctx[:staging].id)
    end

    test "when no secret params are provided then just updates gofer data", ctx do
      assert {:ok, deployment = %Deployment{state: :FINISHED, result: :SUCCESS}} =
               DeploymentQueries.update(ctx[:staging], ctx[:valid_params], :no_secret_params)

      assert deployment.name == ctx[:valid_params][:name]
      assert deployment.description == ctx[:valid_params][:description]

      assert deployment.subject_rules ==
               Enum.map(ctx[:valid_params][:subject_rules], &struct(Deployment.SubjectRule, &1))

      assert deployment.object_rules ==
               Enum.map(ctx[:valid_params][:object_rules], &struct(Deployment.ObjectRule, &1))
    end

    test "when empty payload is provided then just persists result", ctx do
      assert {:ok, deployment = %Deployment{state: :FINISHED, result: :FAILURE}} =
               DeploymentQueries.update(ctx[:prod], ctx[:valid_params], :no_secret_params)

      assert deployment.name == ctx[:valid_params][:name]
      assert deployment.description == ctx[:valid_params][:description]
    end

    test "when requester ID is not provided then returns error", ctx do
      params = Map.drop(ctx[:encrypted_secret_data], [:requester_id])

      assert {:error,
              %Ecto.Changeset{
                errors: [
                  encrypted_secret: {"is invalid", [requester_id: {"can't be blank", _}]}
                ]
              }} = DeploymentQueries.update(ctx[:staging], ctx[:valid_params], params)
    end

    test "when non-empty secret payload is provided and secret was already present then marks for syncing",
         ctx do
      assert {:ok, deployment = %Deployment{state: :SYNCING}} =
               DeploymentQueries.update(
                 ctx[:staging],
                 ctx[:valid_params],
                 ctx[:encrypted_secret_data]
               )

      assert %Deployment.EncryptedSecret{
               request_type: :update,
               error_message: nil
             } = deployment.encrypted_secret

      assert deployment.name == ctx[:valid_params][:name]
      assert deployment.description == ctx[:valid_params][:description]

      assert deployment.subject_rules ==
               Enum.map(ctx[:valid_params][:subject_rules], &struct(Deployment.SubjectRule, &1))

      assert deployment.object_rules ==
               Enum.map(ctx[:valid_params][:object_rules], &struct(Deployment.ObjectRule, &1))

      assert deployment.bookmark_parameter1 == ctx[:valid_params][:bookmark_parameter1]
      assert deployment.bookmark_parameter2 == ctx[:valid_params][:bookmark_parameter2]
      assert deployment.bookmark_parameter3 == ctx[:valid_params][:bookmark_parameter3]
    end

    test "when non-empty secret payload is provided and secret was not present then marks for syncing",
         ctx do
      deployment =
        ctx[:canary]
        |> Ecto.Changeset.change(%{
          state: :FINISHED,
          encrypted_secret: nil
        })
        |> EctoRepo.update!()

      assert {:ok, deployment = %Deployment{state: :SYNCING}} =
               DeploymentQueries.update(
                 deployment,
                 ctx[:valid_params],
                 ctx[:encrypted_secret_data]
               )

      assert %Deployment.EncryptedSecret{
               request_type: :create,
               error_message: nil
             } = deployment.encrypted_secret

      assert deployment.name == ctx[:valid_params][:name]
      assert deployment.description == ctx[:valid_params][:description]

      assert deployment.subject_rules ==
               Enum.map(ctx[:valid_params][:subject_rules], &struct(Deployment.SubjectRule, &1))

      assert deployment.object_rules ==
               Enum.map(ctx[:valid_params][:object_rules], &struct(Deployment.ObjectRule, &1))

      assert deployment.bookmark_parameter1 == ctx[:valid_params][:bookmark_parameter1]
      assert deployment.bookmark_parameter2 == ctx[:valid_params][:bookmark_parameter2]
      assert deployment.bookmark_parameter3 == ctx[:valid_params][:bookmark_parameter3]
    end

    test "when deployment ID and unique token are given then runs transaction", ctx do
      assert {:ok, %Deployment{state: :SYNCING}} =
               DeploymentQueries.update(
                 ctx[:staging].id,
                 ctx[:encrypted_secret_data][:unique_token],
                 ctx[:valid_params],
                 ctx[:encrypted_secret_data]
               )

      assert {:error, {:already_done, %Deployment{state: :SYNCING}}} =
               DeploymentQueries.update(
                 ctx[:staging].id,
                 ctx[:encrypted_secret_data][:unique_token],
                 ctx[:valid_params],
                 ctx[:encrypted_secret_data]
               )

      unique_token = UUID.uuid4()
      secret_data = %{ctx[:encrypted_secret_data] | unique_token: unique_token}

      assert {:error, {:invalid_state, :SYNCING}} =
               DeploymentQueries.update(
                 ctx[:staging].id,
                 unique_token,
                 ctx[:valid_params],
                 secret_data
               )
    end
  end

  describe "cordon/2" do
    test "when deployment is in :SYNCING state then returns error", ctx do
      assert {:error, {:invalid_state, :SYNCING}} =
               DeploymentQueries.delete(ctx[:canary], %{requester_id: ctx[:user_id]})
    end

    test "when deployment is not cordoned and cordoned? = true then changes cordon state", ctx do
      assert {:ok, %Deployment{id: target_id, cordoned: true}} =
               DeploymentQueries.cordon(ctx[:staging], true)

      assert ^target_id = ctx.staging.id
    end

    test "when deployment is not cordoned and cordoned? = false then keeps cordon state", ctx do
      assert {:ok, %Deployment{id: target_id, cordoned: false}} =
               DeploymentQueries.cordon(ctx[:staging], false)

      assert ^target_id = ctx.staging.id
    end

    test "when deployment is cordoned and cordoned? = false then changes cordon state", ctx do
      assert {:ok, %Deployment{id: target_id, cordoned: false}} =
               DeploymentQueries.cordon(ctx[:prod], false)

      assert ^target_id = ctx.prod.id
    end

    test "when deployment is cordoned and cordoned? = true then keeps cordon state", ctx do
      assert {:ok, %Deployment{id: target_id, cordoned: true}} =
               DeploymentQueries.cordon(ctx[:prod], true)

      assert ^target_id = ctx.prod.id
    end
  end

  describe "delete/1" do
    test "when deployment is in :SYNCING state then returns error", ctx do
      assert {:error, {:invalid_state, :SYNCING}} =
               DeploymentQueries.delete(ctx[:canary], %{requester_id: ctx[:user_id]})
    end

    test "when requester ID is not provided then returns error", ctx do
      assert {:error,
              %Ecto.Changeset{
                errors: [
                  encrypted_secret: {"is invalid", [requester_id: {"can't be blank", _}]}
                ]
              }} = DeploymentQueries.delete(ctx[:prod], %{unique_token: UUID.uuid4()})
    end

    test "when unique token is not provided then returns error", ctx do
      assert {:error,
              %Ecto.Changeset{
                errors: [
                  encrypted_secret: {"is invalid", [unique_token: {"can't be blank", _}]}
                ]
              }} = DeploymentQueries.delete(ctx[:prod], %{requester_id: UUID.uuid4()})
    end

    test "when deployment exists and it has secret then marks it for syncing",
         ctx = %{user_id: user_id} do
      assert {:ok, deployment = %Deployment{state: :SYNCING}} =
               DeploymentQueries.delete(ctx[:prod], %{
                 requester_id: user_id,
                 unique_token: UUID.uuid4()
               })

      assert %Deployment.EncryptedSecret{
               request_type: :delete,
               requester_id: ^user_id,
               error_message: nil
             } = deployment.encrypted_secret

      assert deployment.name == ctx[:prod].name
      assert deployment.description == ctx[:prod].description
    end

    test "when deployment exists and it has no secret then marks it for syncing",
         ctx = %{user_id: user_id} do
      deployment =
        ctx[:canary]
        |> Ecto.Changeset.change(%{
          state: :FINISHED,
          encrypted_secret: nil
        })
        |> EctoRepo.update!()

      assert {:ok, deployment = %Deployment{state: :FINISHED}} =
               DeploymentQueries.delete(deployment, %{
                 requester_id: user_id,
                 unique_token: UUID.uuid4()
               })

      assert deployment.name == ctx[:canary].name
      assert deployment.description == ctx[:canary].description

      assert {:error, :not_found} = DeploymentQueries.find_by_id(deployment.id)
    end

    test "when deployment_id and unique_token are given then runs transaction", ctx do
      unique_token = UUID.uuid4()

      assert {:ok, %Deployment{state: :SYNCING}} =
               DeploymentQueries.delete(ctx[:staging].id, unique_token, %{
                 requester_id: ctx.user_id,
                 unique_token: unique_token
               })

      assert {:error, {:already_done, %Deployment{state: :SYNCING}}} =
               DeploymentQueries.delete(ctx[:staging].id, unique_token, %{
                 requester_id: ctx.user_id,
                 unique_token: unique_token
               })

      unique_token = UUID.uuid4()

      assert {:error, {:invalid_state, :SYNCING}} =
               DeploymentQueries.delete(ctx[:staging].id, unique_token, %{
                 requester_id: ctx.user_id,
                 unique_token: unique_token
               })
    end
  end

  describe "scan_syncing/0" do
    setup ctx do
      EctoRepo.delete!(ctx[:canary])
      :ok
    end

    test "when none are configured then return empty list", _ctx do
      assert length(DeploymentQueries.scan_syncing(NaiveDateTime.utc_now(), 0, 5)) == 0
    end

    test "when some are configured then return list of deployments", ctx do
      for i <- 1..12 do
        params = %{ctx[:valid_params] | name: "target_#{i}", unique_token: UUID.uuid4()}

        %Deployment{}
        |> Deployment.changeset(params)
        |> EctoRepo.insert!()
      end

      startup_time = NaiveDateTime.utc_now()
      batch_size = 5

      assert length(DeploymentQueries.scan_syncing(startup_time, 0, batch_size)) == 5
      assert length(DeploymentQueries.scan_syncing(startup_time, 1, batch_size)) == 5
      assert length(DeploymentQueries.scan_syncing(startup_time, 2, batch_size)) == 2
    end
  end

  describe "pass_syncing/2" do
    test "when secret params are invalid then returns error", ctx do
      assert {:error, %Ecto.Changeset{errors: errors}} =
               DeploymentQueries.pass_syncing(ctx[:canary], %{secret_name: "", secret_id: ""})

      assert [secret_id: {"can't be blank", _}, secret_name: {"can't be blank", _}] = errors
    end

    test "when secret params are valid then secret is stored", ctx do
      assert {:ok, deployment = %Deployment{state: :FINISHED, result: :SUCCESS}} =
               DeploymentQueries.pass_syncing(ctx[:canary], ctx[:secret_params])

      assert deployment.id == ctx[:canary].id
      assert is_nil(deployment.encrypted_secret)
      assert deployment.secret_id == ctx[:secret_params][:secret_id]
      assert deployment.secret_name == ctx[:secret_params][:secret_name]
    end
  end

  describe "fail_syncing/2" do
    test "when reason is string then stores it literally", ctx do
      assert {:ok, %Deployment{state: :FINISHED, result: :FAILURE, encrypted_secret: secret}} =
               DeploymentQueries.fail_syncing(ctx[:canary], "timeout")

      prev_secret = ctx[:canary].encrypted_secret

      assert secret.request_type == prev_secret.request_type
      assert secret.key_id == prev_secret.key_id
      assert secret.aes256_key == prev_secret.aes256_key
      assert secret.init_vector == prev_secret.init_vector
      assert secret.payload == prev_secret.payload
      assert secret.error_message == "timeout"
    end

    test "when reason is other term then stores it as string", ctx do
      assert {:ok, %Deployment{state: :FINISHED, result: :FAILURE, encrypted_secret: secret}} =
               DeploymentQueries.fail_syncing(ctx[:canary], :timeout)

      prev_secret = ctx[:canary].encrypted_secret

      assert secret.request_type == prev_secret.request_type
      assert secret.key_id == prev_secret.key_id
      assert secret.aes256_key == prev_secret.aes256_key
      assert secret.init_vector == prev_secret.init_vector
      assert secret.payload == prev_secret.payload
      assert secret.error_message == ":timeout"
    end
  end

  describe "prune_permanently/1" do
    test "removes deployment completely", ctx do
      assert {:ok, %Deployment{id: id, name: "Canary"}} =
               DeploymentQueries.prune_permanently(ctx[:canary])

      assert is_nil(EctoRepo.get(Deployment, id))
    end

    test "works when deployment was used before", ctx do
      assert {:ok, %Deployment{id: id, name: "Staging"}} =
               DeploymentQueries.prune_permanently(ctx[:staging])

      assert is_nil(EctoRepo.get(Deployment, id))

      assert {:ok, %Deployment{id: id, name: "Production"}} =
               DeploymentQueries.prune_permanently(ctx[:prod])

      assert is_nil(EctoRepo.get(Deployment, id))
    end
  end

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE switches CASCADE;")
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")
    :ok
  end

  defp init_ids(_context) do
    {:ok, organization_id: UUID.uuid4(), project_id: UUID.uuid4(), user_id: UUID.uuid4()}
  end

  defp prepare_encrypted_secret_data(_context) do
    {:ok,
     encrypted_secret_data: %{
       request_type: nil,
       error_message: nil,
       requester_id: UUID.uuid4(),
       unique_token: UUID.uuid4(),
       key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
       aes256_key: random_payload(256),
       init_vector: random_payload(256),
       payload: random_payload()
     }}
  end

  defp setup_staging_example(context) do
    {:ok,
     staging:
       Gofer.EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Staging",
         description: "Staging environment",
         url: "https://staging.rtx.com",
         organization_id: context[:organization_id],
         project_id: context[:project_id],
         created_by: context[:user_id],
         updated_by: context[:user_id],
         unique_token: UUID.uuid4(),
         state: :FINISHED,
         result: :SUCCESS,
         encrypted_secret: nil,
         secret_id: UUID.uuid4(),
         secret_name: "Staging secret name",
         subject_rules: [
           %Deployment.SubjectRule{
             type: :USER,
             subject_id: UUID.uuid4()
           }
         ],
         object_rules: [
           %Deployment.ObjectRule{
             type: :BRANCH,
             match_mode: :EXACT,
             pattern: "master"
           }
         ]
       })}
  end

  defp setup_canary_example(context) do
    {:ok,
     canary:
       Gofer.EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Canary",
         description: "Canary environment",
         url: "https://canary.rtx.com",
         organization_id: context[:organization_id],
         project_id: context[:project_id],
         created_by: context[:user_id],
         updated_by: context[:user_id],
         unique_token: UUID.uuid4(),
         state: :SYNCING,
         result: :SUCCESS,
         encrypted_secret:
           struct(Deployment.EncryptedSecret, %{
             context.encrypted_secret_data
             | request_type: :create,
               requester_id: context[:user_id]
           }),
         subject_rules: [
           %Deployment.SubjectRule{
             type: :USER,
             subject_id: UUID.uuid4()
           }
         ],
         object_rules: [
           %Deployment.ObjectRule{
             type: :TAG,
             match_mode: :REGEX,
             pattern: "v1.0.*"
           }
         ]
       })}
  end

  defp setup_production_example(context) do
    {:ok,
     prod:
       Gofer.EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Production",
         description: "Production environment",
         url: "https://prod.rtx.com",
         organization_id: context[:organization_id],
         project_id: context[:project_id],
         created_by: context[:user_id],
         updated_by: context[:user_id],
         unique_token: UUID.uuid4(),
         state: :FINISHED,
         result: :FAILURE,
         cordoned: true,
         secret_id: UUID.uuid4(),
         secret_name: "Production secret name",
         encrypted_secret:
           struct(Deployment.EncryptedSecret, %{
             context.encrypted_secret_data
             | request_type: :update,
               requester_id: context[:user_id],
               unique_token: UUID.uuid4(),
               error_message: "{:invalid_params, [:foo, :bar]}"
           }),
         subject_rules: [
           %Deployment.SubjectRule{
             type: :ROLE,
             subject_id: UUID.uuid4()
           }
         ],
         object_rules: [
           %Deployment.ObjectRule{
             type: :BRANCH,
             match_mode: :REGEX,
             pattern: "release/*"
           }
         ]
       })}
  end

  defp prepare_params(context) do
    {:ok,
     secret_params: %{
       secret_name: "Secret name",
       secret_id: UUID.uuid4()
     },
     valid_params: %{
       name: "deployment_target",
       description: "Some description",
       url: "https://random.com/url",
       organization_id: context[:organization_id],
       project_id: context[:project_id],
       created_by: context[:user_id],
       updated_by: context[:user_id],
       unique_token: UUID.uuid4(),
       subject_rules: [
         %{type: :USER, subject_id: UUID.uuid4()},
         %{type: :ROLE, subject_id: UUID.uuid4()}
       ],
       object_rules: [
         %{type: :BRANCH, match_mode: :EXACT, pattern: "master"}
       ],
       bookmark_parameter1: "environment"
     },
     invalid_params: %{
       name: "",
       description: "",
       url: "",
       organization_id: context[:organization_id],
       project_id: context[:project_id],
       created_by: context[:user_id],
       updated_by: context[:user_id],
       unique_token: UUID.uuid4(),
       subject_rules: [],
       object_rules: []
     }}
  end

  defp setup_switch(_context) do
    alias Gofer.Switch.Model.Switch

    switch =
      %Switch{}
      |> Switch.changeset(%{
        id: UUID.uuid4(),
        ppl_id: UUID.uuid4(),
        prev_ppl_artefact_ids: [UUID.uuid4()],
        branch_name: "master",
        label: "master",
        git_ref_type: "branch"
      })
      |> EctoRepo.insert!()

    {:ok, switch: switch}
  end

  defp setup_deployments(context) do
    now = DateTime.utc_now()

    {:ok, trigger: _first_trigger} =
      insert_trigger(context.switch, context.prod, %{
        triggered_at: DateTime.add(now, -600),
        state: :DONE,
        result: "failed"
      })

    {:ok, trigger: second_trigger} =
      insert_trigger(context.switch, context.prod, %{
        triggered_at: DateTime.add(now, -300),
        state: :DONE,
        result: "passed"
      })

    {:ok, trigger: third_trigger} =
      insert_trigger(context.switch, context.staging, %{
        triggered_at: now,
        state: :STARTING,
        result: nil
      })

    {:ok, prod_trigger: second_trigger, staging_trigger: third_trigger}
  end

  defp insert_trigger(switch, deployment, params) do
    alias Gofer.DeploymentTrigger.Model.DeploymentTrigger, as: Trigger

    defaults = %{
      deployment_id: deployment.id,
      switch_id: switch.id,
      git_ref_type: switch.git_ref_type,
      git_ref_label: switch.label,
      triggered_by: UUID.uuid4(),
      triggered_at: DateTime.utc_now(),
      switch_trigger_id: UUID.uuid4(),
      target_name: "Production",
      request_token: UUID.uuid4(),
      switch_trigger_params: %{"id" => UUID.uuid4()}
    }

    {:ok, trigger: EctoRepo.insert!(struct!(Trigger, Map.merge(defaults, params)))}
  end

  defp random_payload(n_bytes \\ 1_024),
    do: round(n_bytes) |> :crypto.strong_rand_bytes() |> Base.encode64()
end
