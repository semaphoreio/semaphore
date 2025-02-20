defmodule Gofer.Grpc.DeploymentTargets.ServerTest do
  use ExUnit.Case, async: false

  alias InternalApi.Gofer.DeploymentTargets, as: API
  alias API.DeploymentTargets, as: Service
  alias Gofer.EctoRepo

  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Deployment.Engine

  @host "localhost"
  @port 50_055

  @grpc_unknown 2
  @grpc_invalid_argument 3
  @grpc_not_found 5
  @grpc_failed_precondition 9

  setup_all [:prepare_data, :mock_engine, :mock_rbac]

  setup [
    :truncate_database,
    :prepare_encrypted_secret_data,
    :setup_staging_example,
    :setup_canary_example,
    :setup_production_example,
    :setup_switch,
    :setup_deployments,
    :clear_calls
  ]

  describe "rpc Describe(DescribeRequest) returns (DescribeResponse)" do
    test "has no valid data  => :INVALID_ARGUMENT", _ctx do
      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing arguments: target_id or (project_id, target_name)"
              }} = send(API.DescribeRequest.new())
    end

    test "has project_id but no target_name => :INVALID_ARGUMENT", ctx do
      request = API.DescribeRequest.new(project_id: ctx.project_id)

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing arguments: target_id or (project_id, target_name)"
              }} = send(request)
    end

    test "has target_name but no project_id => :INVALID_ARGUMENT", ctx do
      request = API.DescribeRequest.new(target_name: ctx.target_name)

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing arguments: target_id or (project_id, target_name)"
              }} = send(request)
    end

    test "deployment target does not exist by project/target => :NOT_FOUND", ctx do
      request = API.DescribeRequest.new(project_id: UUID.uuid4(), target_name: ctx.target_name)

      assert {:error, %GRPC.RPCError{status: @grpc_not_found, message: "Not found"}} =
               send(request)
    end

    test "deployment target does not exist by ID => :NOT_FOUND", _ctx do
      request = API.DescribeRequest.new(target_id: UUID.uuid4())

      assert {:error, %GRPC.RPCError{status: @grpc_not_found, message: "Not found"}} =
               send(request)
    end

    test "deployment target exists by ID => :OK", ctx do
      request = API.DescribeRequest.new(target_id: ctx.staging.id)
      subject_id = ctx.user_id

      assert {:ok,
              %API.DescribeResponse{
                target: %API.DeploymentTarget{
                  name: "Staging",
                  description: "Staging environment",
                  bookmark_parameter1: "environment",
                  subject_rules: [
                    %API.SubjectRule{type: :USER, subject_id: ^subject_id}
                  ],
                  object_rules: [
                    %API.ObjectRule{type: :BRANCH, match_mode: :EXACT, pattern: "master"}
                  ],
                  state: :UNUSABLE,
                  state_message: "{:invalid_params, [:foo, :bar]}",
                  secret_name: "Staging secret name"
                }
              }} = send(request)
    end

    test "deployment target exists by project and target => :OK",
         ctx = %{role_id: role_id, user_id: user_id} do
      assert {:ok,
              %API.DescribeResponse{
                target: %API.DeploymentTarget{
                  name: "Production",
                  description: "Production environment",
                  subject_rules: [
                    %API.SubjectRule{type: :ROLE, subject_id: ^role_id},
                    %API.SubjectRule{type: :USER, subject_id: ^user_id}
                  ],
                  object_rules: [
                    %API.ObjectRule{type: :BRANCH, match_mode: :REGEX, pattern: "release/.*"},
                    %API.ObjectRule{type: :BRANCH, match_mode: :EXACT, pattern: "master"},
                    %API.ObjectRule{type: :PR, match_mode: :ALL, pattern: ""}
                  ],
                  state: :USABLE,
                  state_message: ""
                }
              }} =
               send(
                 API.DescribeRequest.new(project_id: ctx.project_id, target_name: ctx.prod.name)
               )
    end

    test "sends metrics via watchman", ctx do
      mock_watchman()

      assert {:ok, %API.DescribeResponse{}} =
               send(API.DescribeRequest.new(target_id: ctx.staging.id))

      assert_watched?({"Gofer.grpc.deployment-targets.describe", ["OK"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.describe", :timing)

      assert {:error, %GRPC.RPCError{}} = send(API.DescribeRequest.new(target_id: UUID.uuid4()))

      assert_watched?({"Gofer.grpc.deployment-targets.describe", ["NotFound"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.describe", :timing)
    end
  end

  describe "rpc Verify(VerifyRequest) returns (VerifyResponse)" do
    test "has no valid data => :INVALID_ARGUMENT", _ctx do
      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: target_id"
              }} = send(API.VerifyRequest.new())

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: triggerer"
              }} = send(API.VerifyRequest.new(target_id: "target_id"))

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: git_ref_label"
              }} = send(API.VerifyRequest.new(target_id: "target_id", triggerer: "triggerer"))
    end

    test "deployment target does not exist => :NOT_FOUND", ctx do
      assert {:error, %GRPC.RPCError{status: @grpc_not_found, message: message}} =
               send(
                 API.VerifyRequest.new(
                   target_id: UUID.uuid4(),
                   triggerer: ctx.user_id,
                   git_ref_type: :BRANCH,
                   git_ref_label: "master"
                 )
               )

      assert String.starts_with?(message, "Target")
      assert String.ends_with?(message, "not found")
    end

    test "deployment target is corrupted => :CORRUPTED_TARGET", ctx do
      assert {:ok, %API.VerifyResponse{status: :CORRUPTED_TARGET}} =
               send(
                 API.VerifyRequest.new(
                   target_id: ctx.staging.id,
                   triggerer: ctx.user_id,
                   git_ref_type: :BRANCH,
                   git_ref_label: "master"
                 )
               )
    end

    test "deployment target is synced and unavailable to user => :BANNED_SUBJECT", ctx do
      assert {:ok, %API.VerifyResponse{status: :BANNED_SUBJECT}} =
               send(
                 API.VerifyRequest.new(
                   target_id: ctx.prod.id,
                   triggerer: UUID.uuid4(),
                   git_ref_type: :BRANCH,
                   git_ref_label: "master"
                 )
               )
    end

    test "deployment target is synced and unavailable for branch => :BANNED_OBJECT", ctx do
      assert {:ok, %API.VerifyResponse{status: :BANNED_OBJECT}} =
               send(
                 API.VerifyRequest.new(
                   target_id: ctx.prod.id,
                   triggerer: ctx.user_id,
                   git_ref_type: :BRANCH,
                   git_ref_label: "develop"
                 )
               )
    end

    test "deployment target is synced and available => :ACCESS_GRANTED", ctx do
      assert {:ok, %API.VerifyResponse{status: :ACCESS_GRANTED}} =
               send(
                 API.VerifyRequest.new(
                   target_id: ctx.prod.id,
                   triggerer: ctx.user_id,
                   git_ref_type: :BRANCH,
                   git_ref_label: "master"
                 )
               )
    end
  end

  describe "rpc History(HistoryRequest) returns (HistoryResponse)" do
    test "has no valid data  => :INVALID_ARGUMENT", _ctx do
      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: target_id"
              }} = send(API.HistoryRequest.new())
    end

    test "deployment target does not exist => :NOT_FOUND", _ctx do
      assert {:error, %GRPC.RPCError{status: @grpc_not_found, message: message}} =
               send(API.HistoryRequest.new(target_id: UUID.uuid4()))

      assert String.starts_with?(message, "Target")
      assert String.ends_with?(message, "not found")
    end

    test "deployment target exists and has no deployments => empty list", ctx do
      EctoRepo.delete(ctx.staging_trigger)

      assert {:ok, %API.HistoryResponse{deployments: [], cursor_before: 0, cursor_after: 0}} =
               send(API.HistoryRequest.new(target_id: ctx.staging.id))
    end

    test "deployment target exists and has deployments => list of n latest", ctx do
      assert {:ok, response = %API.HistoryResponse{deployments: deployments}} =
               send(API.HistoryRequest.new(target_id: ctx.prod.id, requester_id: ctx.user_id))

      assert [first_deployment, second_deployment] = deployments
      assert Enum.all?(deployments, &UUID.info!(&1.id))
      assert Enum.all?(deployments, &UUID.info!(&1.target_id))
      assert Enum.all?(deployments, &UUID.info!(&1.prev_pipeline_id))
      assert Enum.all?(deployments, &UUID.info!(&1.triggered_by))
      assert Enum.all?(deployments, &(&1.switch_id == ctx.switch.id))
      assert Enum.all?(deployments, &(&1.target_name == "Production"))
      assert Enum.all?(deployments, &match?(%Google.Protobuf.Timestamp{}, &1.triggered_at))
      assert Enum.all?(deployments, &Enum.member?(~w(STARTED FAILED PENDING)a, &1.state))
      assert env_vars = MapSet.new([API.Deployment.EnvVar.new(name: "varname", value: "foobar")])
      assert Enum.all?(deployments, &(&1.env_vars |> MapSet.new() |> MapSet.equal?(env_vars)))
      assert Enum.all?(deployments, & &1.can_requester_rerun)

      assert first_deployment.triggered_at.seconds >= second_deployment.triggered_at.seconds
      assert response.cursor_before == 0
      assert response.cursor_after == 0
    end

    test "deployment target exists and has many deployments => list page with cursors", ctx do
      for i <- 3..30 do
        insert_trigger(ctx.switch, ctx.prod, %{
          triggered_at: DateTime.utc_now() |> DateTime.add(-300 * i),
          pipeline_id: UUID.uuid4(),
          state: :DONE,
          result: "passed"
        })
      end

      assert {:ok, response = %API.HistoryResponse{deployments: deployments}} =
               send(
                 API.HistoryRequest.new(
                   target_id: ctx.prod.id,
                   requester_id: ctx.user_id,
                   cursor_type: :BEFORE,
                   cursor_value:
                     DateTime.utc_now()
                     |> DateTime.add(-3000)
                     |> DateTime.to_unix(:microsecond)
                 )
               )

      assert Enum.count(deployments) == 10
      assert Enum.all?(deployments, &UUID.info!(&1.id))
      assert Enum.all?(deployments, &UUID.info!(&1.target_id))
      assert Enum.all?(deployments, &UUID.info!(&1.prev_pipeline_id))
      assert Enum.all?(deployments, &UUID.info!(&1.triggered_by))
      assert Enum.all?(deployments, &(&1.switch_id == ctx.switch.id))
      assert Enum.all?(deployments, &(&1.target_name == "Production"))
      assert Enum.all?(deployments, &match?(%Google.Protobuf.Timestamp{}, &1.triggered_at))
      assert Enum.all?(deployments, &Enum.member?(~w(STARTED FAILED PENDING)a, &1.state))
      assert Enum.all?(deployments, & &1.can_requester_rerun)

      assert_in_delta response.cursor_before,
                      DateTime.utc_now()
                      |> DateTime.add(-6000)
                      |> DateTime.to_unix(:microsecond),
                      1_000_000

      assert_in_delta response.cursor_after,
                      DateTime.utc_now()
                      |> DateTime.add(-3300)
                      |> DateTime.to_unix(:microsecond),
                      1_000_000
    end

    test "deployment target has many deployments and filters are passed => list page", ctx do
      send_with_filters = fn filters ->
        send(
          API.HistoryRequest.new(
            target_id: ctx.prod.id,
            filters: API.HistoryRequest.Filters.new(filters)
          )
        )
      end

      assert {:ok, %API.HistoryResponse{deployments: [_first, _second]}} =
               send_with_filters.(git_ref_type: "branch")

      assert {:ok, %API.HistoryResponse{deployments: []}} =
               send_with_filters.(git_ref_type: "branch", git_ref_label: "develop")

      assert {:ok, %API.HistoryResponse{deployments: []}} =
               send_with_filters.(git_ref_type: "tag")

      assert {:ok, %API.HistoryResponse{deployments: []}} =
               send_with_filters.(triggered_by: UUID.uuid4())

      assert {:ok, %API.HistoryResponse{deployments: []}} = send_with_filters.(parameter1: "test")
      assert {:ok, %API.HistoryResponse{deployments: []}} = send_with_filters.(parameter2: "test")
      assert {:ok, %API.HistoryResponse{deployments: []}} = send_with_filters.(parameter3: "test")
    end

    test "sends metrics via watchman", ctx do
      mock_watchman()

      assert {:ok, %API.HistoryResponse{}} =
               send(API.HistoryRequest.new(target_id: ctx.staging.id))

      assert_watched?({"Gofer.grpc.deployment-targets.history", ["OK"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.history", :timing)

      assert {:error, %GRPC.RPCError{}} = send(API.HistoryRequest.new(target_id: UUID.uuid4()))

      assert_watched?({"Gofer.grpc.deployment-targets.history", ["NotFound"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.history", :timing)
    end
  end

  describe "rpc List(ListRequest) returns (ListResponse)" do
    test "has no valid data  => :INVALID_ARGUMENT", _ctx do
      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: project_id"
              }} = send(API.ListRequest.new())
    end

    test "has no targets  => :OK with empty list", _ctx do
      assert {:ok, %API.ListResponse{targets: []}} =
               send(API.ListRequest.new(project_id: UUID.uuid4()))
    end

    test "has some targets  => :OK with non-empty list", ctx do
      target_names = MapSet.new(["Production", "Staging"])

      assert {:ok, %API.ListResponse{targets: targets}} =
               send(API.ListRequest.new(project_id: ctx.project_id))

      assert targets |> MapSet.new(& &1.name) |> MapSet.equal?(target_names)
    end

    test "targets have deployments => :OK with non-empty list", ctx do
      assert {:ok, %API.ListResponse{targets: targets}} =
               send(API.ListRequest.new(project_id: ctx.project_id, requester_id: ctx.user_id))

      assert targets |> Enum.find(&(&1.id == ctx.prod.id)) |> Map.get(:last_deployment) ==
               %API.Deployment{
                 id: ctx.prod_trigger.id,
                 target_id: ctx.prod.id,
                 prev_pipeline_id: ctx.switch.ppl_id,
                 pipeline_id: ctx.prod_trigger.pipeline_id,
                 triggered_by: ctx.prod_trigger.triggered_by,
                 triggered_at:
                   Google.Protobuf.Timestamp.new(
                     seconds: DateTime.to_unix(ctx.prod_trigger.triggered_at)
                   ),
                 state: :STARTED,
                 state_message: "",
                 switch_id: ctx.switch.id,
                 target_name: "Production",
                 env_vars: [%API.Deployment.EnvVar{name: "varname", value: "foobar"}],
                 can_requester_rerun: true
               }

      assert targets |> Enum.find(&(&1.id == ctx.staging.id)) |> Map.get(:last_deployment) ==
               %API.Deployment{
                 id: ctx.staging_trigger.id,
                 target_id: ctx.staging.id,
                 prev_pipeline_id: ctx.switch.ppl_id,
                 pipeline_id: "",
                 triggered_by: ctx.staging_trigger.triggered_by,
                 triggered_at:
                   Google.Protobuf.Timestamp.new(
                     seconds: DateTime.to_unix(ctx.staging_trigger.triggered_at)
                   ),
                 state: :PENDING,
                 state_message: "",
                 switch_id: ctx.switch.id,
                 target_name: "Production",
                 env_vars: [%API.Deployment.EnvVar{name: "varname", value: "foobar"}],
                 can_requester_rerun: false
               }
    end

    test "sends metrics via watchman", ctx do
      mock_watchman()

      assert {:ok, %API.ListResponse{}} = send(API.ListRequest.new(project_id: ctx.project_id))

      assert_watched?({"Gofer.grpc.deployment-targets.list", ["OK"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.list", :timing)
    end
  end

  describe "rpc Cordon(CordonRequest) returns (CordonResponse)" do
    test "has empty target ID  => :INVALID_ARGUMENT", _ctx do
      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: target_id"
              }} = send(API.CordonRequest.new())
    end

    test "deployment target does not exist => :NOT_FOUND", _ctx do
      assert {:error, %GRPC.RPCError{status: @grpc_not_found, message: "Target not found:" <> _}} =
               send(API.CordonRequest.new(target_id: UUID.uuid4()))
    end

    test "deployment is syncing => :FAILED_PRECONDITION", ctx do
      ctx.staging
      |> Ecto.Changeset.change(%{state: :SYNCING})
      |> Gofer.EctoRepo.update!()

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_failed_precondition,
                message: "Invalid state: SYNCING"
              }} = send(API.CordonRequest.new(target_id: ctx.staging.id))
    end

    test "deployment is not cordoned => :OK", ctx do
      assert %Deployment{cordoned: false} = EctoRepo.get(Deployment, ctx.staging.id)

      assert {:ok, %API.CordonResponse{cordoned: true}} =
               send(API.CordonRequest.new(target_id: ctx.staging.id, cordoned: true))

      assert {:ok, %API.DescribeResponse{target: %API.DeploymentTarget{state: :CORDONED}}} =
               send(API.DescribeRequest.new(target_id: ctx.staging.id))

      assert %Deployment{cordoned: true} = EctoRepo.get(Deployment, ctx.staging.id)

      assert {:ok, %API.CordonResponse{cordoned: true}} =
               send(API.CordonRequest.new(target_id: ctx.staging.id, cordoned: true))

      assert %Deployment{cordoned: true} = EctoRepo.get(Deployment, ctx.staging.id)
    end

    test "deployment is cordoned => :OK", ctx do
      ctx.staging
      |> Ecto.Changeset.change(%{cordoned: true})
      |> Gofer.EctoRepo.update!()

      assert %Deployment{cordoned: true} = EctoRepo.get(Deployment, ctx.staging.id)

      assert {:ok, %API.CordonResponse{cordoned: false}} =
               send(API.CordonRequest.new(target_id: ctx.staging.id, cordoned: false))

      assert %Deployment{cordoned: false} = EctoRepo.get(Deployment, ctx.staging.id)

      assert {:ok, %API.CordonResponse{cordoned: false}} =
               send(API.CordonRequest.new(target_id: ctx.staging.id, cordoned: false))

      assert %Deployment{cordoned: false} = EctoRepo.get(Deployment, ctx.staging.id)
    end

    test "sends metrics via watchman", ctx do
      mock_watchman()

      assert {:ok, %API.CordonResponse{}} = send(API.CordonRequest.new(target_id: ctx.staging.id))

      assert_watched?({"Gofer.grpc.deployment-targets.cordon", ["OK"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.cordon", :timing)

      assert {:error, %GRPC.RPCError{}} = send(API.CordonRequest.new(target_id: UUID.uuid4()))

      assert_watched?({"Gofer.grpc.deployment-targets.cordon", ["NotFound"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.cordon", :timing)
    end
  end

  describe "rpc Create(CreateRequest) returns (CreateResponse)" do
    test "has no target  => :INVALID_ARGUMENT", ctx do
      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: target"
              }} =
               send(
                 API.CreateRequest.new(
                   secret: ctx.secret_request,
                   requester_id: ctx.user_id,
                   unique_token: UUID.uuid4()
                 )
               )
    end

    test "has name missing => :INVALID_ARGUMENT", ctx do
      request =
        API.CreateRequest.new(
          target: %{ctx.canary | name: ""},
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Changeset error"
              }} = send(request)
    end

    test "has missing branch pattern => :INVALID_ARGUMENT", ctx do
      target = %{
        ctx.canary
        | object_rules: [API.ObjectRule.new(type: :BRANCH, match_mode: :EXACT)]
      }

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Changeset error"
              }} =
               send(
                 API.CreateRequest.new(
                   target: target,
                   secret: ctx.secret_request,
                   requester_id: ctx.user_id,
                   unique_token: UUID.uuid4()
                 )
               )
    end

    test "has requester_id missing => :INVALID_ARGUMENT", ctx do
      request =
        API.CreateRequest.new(
          target: ctx.canary,
          secret: ctx.secret_request,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: requester_id"
              }} = send(request)
    end

    test "has unique_token missing => :INVALID_ARGUMENT", ctx do
      request =
        API.CreateRequest.new(
          target: ctx.canary,
          secret: ctx.secret_request,
          user_id: ctx.user_id
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: unique_token"
              }} = send(request)
    end

    test "worker cannot be started => :UNKNOWN", ctx do
      set_engine_response({:error, :max_children})

      request =
        API.CreateRequest.new(
          target: ctx.canary,
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_unknown,
                message: "Unable to create DT"
              }} = send(request)
    end

    test "has no secret request => :OK", ctx do
      request =
        API.CreateRequest.new(
          target: ctx.canary,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      subject_rules = ctx.canary.subject_rules
      object_rules = ctx.canary.object_rules

      assert {:ok,
              %API.CreateResponse{
                target: %API.DeploymentTarget{
                  name: "Canary",
                  description: "Canary environment",
                  bookmark_parameter1: "environment",
                  subject_rules: ^subject_rules,
                  object_rules: ^object_rules,
                  state: :USABLE
                }
              }} = send(request)
    end

    test "has proper payload => :OK", ctx do
      request =
        API.CreateRequest.new(
          target: ctx.canary,
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      subject_rules = ctx.canary.subject_rules
      object_rules = ctx.canary.object_rules

      assert {:ok,
              %API.CreateResponse{
                target: %API.DeploymentTarget{
                  id: deployment_id,
                  name: "Canary",
                  description: "Canary environment",
                  bookmark_parameter1: "environment",
                  subject_rules: ^subject_rules,
                  object_rules: ^object_rules,
                  cordoned: false,
                  state: :SYNCING
                }
              }} = send(request)

      assert_worker_started(deployment_id)
    end

    test "call is idempotent", ctx do
      request =
        API.CreateRequest.new(
          target: ctx.canary,
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:ok,
              %API.CreateResponse{
                target: %API.DeploymentTarget{id: deployment_id}
              }} = send(request)

      assert {:ok,
              %API.CreateResponse{
                target: %API.DeploymentTarget{id: ^deployment_id}
              }} = send(request)

      assert_worker_started(deployment_id)
    end

    test "sends metrics via watchman", ctx do
      mock_watchman()

      assert {:ok, %API.CreateResponse{}} =
               send(
                 API.CreateRequest.new(
                   target: ctx.canary,
                   secret: ctx.secret_request,
                   requester_id: ctx.user_id,
                   unique_token: UUID.uuid4()
                 )
               )

      assert_watched?({"Gofer.grpc.deployment-targets.create", ["OK"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.create", :timing)
    end
  end

  describe "rpc Update(UpdateRequest) returns (UpdateResponse)" do
    test "has no target  => :INVALID_ARGUMENT", ctx do
      request =
        API.UpdateRequest.new(
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: target"
              }} = send(request)
    end

    test "has id missing => :NOT_FOUND", ctx do
      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ""},
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_not_found,
                message: "Target not found: empty target ID"
              }} = send(request)
    end

    test "has random id => :NOT_FOUND", ctx do
      target_id = UUID.uuid4()

      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: target_id},
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      message = "Target not found: #{target_id}"

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_not_found,
                message: ^message
              }} = send(request)
    end

    test "has name missing => :INVALID_ARGUMENT", ctx do
      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ctx.staging.id, name: ""},
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Changeset error"
              }} = send(request)
    end

    test "has missing branch pattern => :INVALID_ARGUMENT", ctx do
      target = %{
        ctx.canary
        | id: ctx.staging.id,
          object_rules: [API.ObjectRule.new(type: :BRANCH, match_mode: :EXACT)]
      }

      request =
        API.UpdateRequest.new(
          target: target,
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Changeset error"
              }} = send(request)
    end

    test "has request without requester_id => :INVALID_ARGUMENT", ctx do
      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ctx.staging.id},
          secret: ctx.secret_request,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: requester_id"
              }} = send(request)
    end

    test "has request without unique_token => :INVALID_ARGUMENT", ctx do
      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ctx.staging.id},
          secret: ctx.secret_request,
          requester_id: ctx.user_id
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: unique_token"
              }} = send(request)
    end

    test "deployment is syncing => :FAILED_PRECONDITION", ctx do
      ctx.staging
      |> Ecto.Changeset.change(%{state: :SYNCING})
      |> Gofer.EctoRepo.update!()

      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ctx.staging.id},
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_failed_precondition,
                message: "Invalid state: SYNCING"
              }} = send(request)
    end

    test "worker cannot be started => :UNKNOWN", ctx do
      set_engine_response({:error, :max_children})

      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ctx.staging.id},
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_unknown,
                message: "Unable to update DT"
              }} = send(request)
    end

    test "has no secret request => :OK", ctx do
      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ctx.staging.id},
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      subject_rules = ctx.canary.subject_rules
      object_rules = ctx.canary.object_rules
      deployment_id = ctx.staging.id

      assert {:ok,
              %API.UpdateResponse{
                target: %API.DeploymentTarget{
                  id: ^deployment_id,
                  name: "Canary",
                  description: "Canary environment",
                  bookmark_parameter1: "environment",
                  subject_rules: ^subject_rules,
                  object_rules: ^object_rules,
                  state: :UNUSABLE,
                  cordoned: false
                }
              }} = send(request)
    end

    test "has secret request => :OK", ctx do
      ctx.staging
      |> Ecto.Changeset.change(%{cordoned: true})
      |> Gofer.EctoRepo.update!()

      assert %Deployment{cordoned: true} = EctoRepo.get(Deployment, ctx.staging.id)

      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ctx.staging.id},
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      subject_rules = ctx.canary.subject_rules
      object_rules = ctx.canary.object_rules
      deployment_id = ctx.staging.id

      assert {:ok,
              %API.UpdateResponse{
                target: %API.DeploymentTarget{
                  id: ^deployment_id,
                  name: "Canary",
                  description: "Canary environment",
                  bookmark_parameter1: "environment",
                  subject_rules: ^subject_rules,
                  object_rules: ^object_rules,
                  state: :SYNCING,
                  cordoned: true
                }
              }} = send(request)

      assert_worker_started(deployment_id)
    end

    test "call is idempotent", ctx do
      deployment_id = ctx.staging.id

      request =
        API.UpdateRequest.new(
          target: %{ctx.canary | id: ctx.staging.id},
          secret: ctx.secret_request,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:ok,
              %API.UpdateResponse{
                target: %API.DeploymentTarget{id: ^deployment_id}
              }} = send(request)

      assert {:ok,
              %API.UpdateResponse{
                target: %API.DeploymentTarget{id: ^deployment_id}
              }} = send(request)

      assert_worker_started(deployment_id)
    end

    test "sends metrics via watchman", ctx do
      mock_watchman()

      assert {:ok, %API.UpdateResponse{}} =
               send(
                 API.UpdateRequest.new(
                   target: %{ctx.canary | id: ctx.staging.id},
                   secret: ctx.secret_request,
                   requester_id: ctx.user_id,
                   unique_token: UUID.uuid4()
                 )
               )

      assert_watched?({"Gofer.grpc.deployment-targets.update", ["OK"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.update", :timing)
    end
  end

  describe "rpc Delete(DeleteRequest) returns (DeleteResponse)" do
    test "has no target_id  => :INVALID_ARGUMENT", ctx do
      request = API.DeleteRequest.new(requester_id: ctx.user_id, unique_token: UUID.uuid4())

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: target_id"
              }} = send(request)
    end

    test "has no requester_id  => :INVALID_ARGUMENT", ctx do
      request = API.DeleteRequest.new(target_id: ctx.prod.id, unique_token: UUID.uuid4())

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: requester_id"
              }} = send(request)
    end

    test "has no unique_token  => :INVALID_ARGUMENT", ctx do
      request = API.DeleteRequest.new(target_id: ctx.prod.id, requester_id: ctx.user_id)

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_invalid_argument,
                message: "Missing argument: unique_token"
              }} = send(request)
    end

    test "has random id => :NOT_FOUND", ctx do
      target_id = UUID.uuid4()

      request =
        API.DeleteRequest.new(
          target_id: target_id,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:ok,
              %API.DeleteResponse{
                target_id: ^target_id
              }} = send(request)
    end

    test "deployment is syncing => :FAILED_PRECONDITION", ctx do
      ctx.prod
      |> Ecto.Changeset.change(%{state: :SYNCING})
      |> Gofer.EctoRepo.update!()

      request =
        API.DeleteRequest.new(
          target_id: ctx.prod.id,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_failed_precondition,
                message: "Invalid state: SYNCING"
              }} = send(request)
    end

    test "worker cannot be started => :UNKNOWN", ctx do
      set_engine_response({:error, :max_children})

      request =
        API.DeleteRequest.new(
          target_id: ctx.prod.id,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      assert {:error,
              %GRPC.RPCError{
                status: @grpc_unknown,
                message: "Unable to delete DT"
              }} = send(request)
    end

    test "has proper payload => :OK", ctx do
      request =
        API.DeleteRequest.new(
          target_id: ctx.prod.id,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      deployment_id = ctx.prod.id

      assert {:ok,
              %API.DeleteResponse{
                target_id: ^deployment_id
              }} = send(request)

      assert_worker_started(deployment_id)
    end

    test "call is idempotent", ctx do
      request =
        API.DeleteRequest.new(
          target_id: ctx.prod.id,
          requester_id: ctx.user_id,
          unique_token: UUID.uuid4()
        )

      deployment_id = ctx.prod.id

      assert {:ok, %API.DeleteResponse{target_id: ^deployment_id}} = send(request)
      assert {:ok, %API.DeleteResponse{target_id: ^deployment_id}} = send(request)

      assert_worker_started(deployment_id)
    end

    test "sends metrics via watchman", ctx do
      mock_watchman()

      assert {:ok, %API.DeleteResponse{}} =
               send(
                 API.DeleteRequest.new(
                   target_id: ctx.prod.id,
                   requester_id: ctx.user_id,
                   unique_token: UUID.uuid4()
                 )
               )

      assert_watched?({"Gofer.grpc.deployment-targets.delete", ["OK"]}, :gauge)
      assert_watched?("Gofer.grpc.deployment-targets.delete", :timing)
    end
  end

  #
  # gRPC send helper function
  #

  defp send(%API.DescribeRequest{} = request), do: do_send(request, :describe)
  defp send(%API.VerifyRequest{} = request), do: do_send(request, :verify)
  defp send(%API.HistoryRequest{} = request), do: do_send(request, :history)
  defp send(%API.ListRequest{} = request), do: do_send(request, :list)
  defp send(%API.CordonRequest{} = request), do: do_send(request, :cordon)
  defp send(%API.CreateRequest{} = request), do: do_send(request, :create)
  defp send(%API.UpdateRequest{} = request), do: do_send(request, :update)
  defp send(%API.DeleteRequest{} = request), do: do_send(request, :delete)

  defp do_send(request, fun) do
    case GRPC.Stub.connect("#{@host}:#{@port}") do
      {:ok, channel} -> do_send(channel, request, fun)
      {:error, _reason} = error -> error
    end
  end

  defp do_send(channel, request, fun),
    do: apply(Service.Stub, fun, [channel, request]),
    after: GRPC.Stub.disconnect(channel)

  #
  # Setup functions
  #

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")
    :ok
  end

  defp prepare_data(_context) do
    {:ok,
     organization_id: UUID.uuid4(),
     project_id: UUID.uuid4(),
     user_id: UUID.uuid4(),
     role_id: UUID.uuid4(),
     secret_id: UUID.uuid4(),
     target_name: "target name"}
  end

  defp mock_engine(_context) do
    start_supervised!({Test.MockDynamicSupervisor, [name: Engine.Supervisor]})
    :ok
  end

  defp mock_rbac(context) do
    role = {context.organization_id, context.project_id, context.user_id, context.role_id}

    start_supervised!(Gofer.RBAC.RolesCache)
    Support.Stubs.RBAC.setup()
    Support.Stubs.RBAC.set_role(role)
  end

  defp set_engine_response(response) do
    Test.MockDynamicSupervisor.set_response(Engine.Supervisor, response)
    on_exit(fn -> Test.MockDynamicSupervisor.clear_response(Engine.Supervisor) end)
  end

  defp clear_calls(_context) do
    {:ok, _calls} = Test.MockDynamicSupervisor.clear_calls(Engine.Supervisor)
    :ok
  end

  defp assert_worker_started(deployment_id) do
    assert {:ok, [{^deployment_id, _pid}]} =
             Test.MockDynamicSupervisor.get_calls(Engine.Supervisor)
  end

  defp prepare_encrypted_secret_data(_context) do
    {:ok,
     secret_request:
       API.EncryptedSecretData.new(
         key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
         aes256_key: random_payload(256),
         init_vector: random_payload(256),
         payload: random_payload()
       )}
  end

  defp mock_watchman do
    watchman_pid = Process.whereis(Watchman.Server)
    Process.unregister(Watchman.Server)
    Process.register(self(), Watchman.Server)

    on_exit(fn ->
      Process.register(watchman_pid, Watchman.Server)
    end)
  end

  defp assert_watched?(metric, type) do
    assert_received {:"$gen_cast", {:send, ^metric, _, ^type}}
  end

  defp setup_staging_example(context) do
    {:ok,
     staging:
       Gofer.EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Staging",
         description: "Staging environment",
         url: "https://staging.rtx.com/",
         bookmark_parameter1: "environment",
         organization_id: context[:organization_id],
         project_id: context[:project_id],
         created_by: context[:user_id],
         updated_by: context[:user_id],
         unique_token: UUID.uuid4(),
         state: :FINISHED,
         result: :FAILURE,
         encrypted_secret: %Deployment.EncryptedSecret{
           request_type: :update,
           requester_id: context[:user_id],
           key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
           unique_token: context[:unique_token],
           aes256_key: random_payload(256),
           init_vector: random_payload(256),
           payload: random_payload(),
           error_message: "{:invalid_params, [:foo, :bar]}"
         },
         secret_id: context[:secret_id],
         secret_name: "Staging secret name",
         subject_rules: [
           %Deployment.SubjectRule{
             type: :USER,
             subject_id: context[:user_id]
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
       API.DeploymentTarget.new(
         name: "Canary",
         description: "Canary environment",
         url: "https://canary.rtx.com/",
         bookmark_parameter1: "environment",
         organization_id: context[:organization_id],
         project_id: context[:project_id],
         subject_rules: [
           API.SubjectRule.new(
             type: :USER,
             subject_id: context[:user_id]
           )
         ],
         object_rules: [
           API.ObjectRule.new(
             type: :TAG,
             match_mode: :REGEX,
             pattern: "v1.0.*"
           ),
           API.ObjectRule.new(
             type: :PR,
             match_mode: :ALL,
             pattern: ""
           )
         ]
       )}
  end

  defp setup_production_example(context) do
    {:ok,
     prod:
       Gofer.EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Production",
         description: "Production environment",
         url: "https://production.rtx.com",
         bookmark_parameter1: "environment",
         organization_id: context[:organization_id],
         project_id: context[:project_id],
         created_by: context[:user_id],
         updated_by: context[:user_id],
         unique_token: UUID.uuid4(),
         state: :FINISHED,
         result: :SUCCESS,
         secret_id: context[:secret_id],
         secret_name: "Production secret name",
         subject_rules: [
           %Deployment.SubjectRule{
             type: :ROLE,
             subject_id: context[:role_id]
           },
           %Deployment.SubjectRule{
             type: :USER,
             subject_id: context[:user_id]
           }
         ],
         object_rules: [
           %Deployment.ObjectRule{
             type: :BRANCH,
             match_mode: :REGEX,
             pattern: "release/.*"
           },
           %Deployment.ObjectRule{
             type: :BRANCH,
             match_mode: :EXACT,
             pattern: "master"
           },
           %Deployment.ObjectRule{
             type: :PR,
             match_mode: :ALL,
             pattern: ""
           }
         ]
       })}
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
        result: "failed",
        reason: "banned_subject"
      })

    {:ok, trigger: second_trigger} =
      insert_trigger(context.switch, context.prod, %{
        triggered_at: DateTime.add(now, -300),
        pipeline_id: UUID.uuid4(),
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
      switch_trigger_params: %{
        "id" => UUID.uuid4(),
        "env_vars_for_target" => %{
          "Production" => [
            %{
              "name" => "varname",
              "value" => "foobar"
            }
          ]
        }
      }
    }

    {:ok, trigger: EctoRepo.insert!(struct!(Trigger, Map.merge(defaults, params)))}
  end

  defp random_payload(n_bytes \\ 1_024),
    do: round(n_bytes) |> :crypto.strong_rand_bytes() |> Base.encode64()
end
