defmodule Gofer.Grpc.Server.Test do
  use ExUnit.Case

  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.Switch.Engine.SwitchSupervisor, as: SSupervisor
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
  alias Gofer.TargetTrigger.Engine.TargetTriggerSupervisor, as: TTSupervisor

  alias InternalApi.Gofer.{
    VersionRequest,
    Switch,
    CreateRequest,
    CreateResponse,
    ResponseStatus,
    Target,
    PipelineDoneRequest,
    PipelineDoneResponse,
    DescribeRequest,
    DescribeResponse,
    TargetDescription,
    TriggerEvent,
    ListTriggerEventsRequest,
    ListTriggerEventsResponse,
    TriggerRequest,
    TriggerResponse,
    ParamEnvVar,
    EnvVariable,
    AutoTriggerCond
  }

  alias Test.Helpers
  alias Google.Protobuf.Timestamp
  alias Util.Proto

  @grpc_port 50054

  setup_all do
    GRPC.Server.start(Test.MockPlumberService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockPlumberService)
    end)

    {:ok, %{}}
  end

  setup do
    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    assert {:ok, dpl} =
             DeploymentQueries.create(
               %{
                 name: "canary",
                 organization_id: UUID.uuid4(),
                 project_id: UUID.uuid4(),
                 unique_token: UUID.uuid4(),
                 created_by: UUID.uuid4(),
                 updated_by: UUID.uuid4()
               },
               :no_secret_params
             )

    switch_def = %{
      "id" => UUID.uuid4(),
      "ppl_id" => UUID.uuid4(),
      "prev_ppl_artefact_ids" => [],
      "branch_name" => "master",
      "project_id" => dpl.project_id,
      "git_ref_type" => "branch",
      "label" => "master"
    }

    target_1 = %{
      "name" => "staging",
      "pipeline_path" => "./stg.yml",
      "auto_trigger_on" => [%{"result" => "passed", "branch" => ["mast.", "xyz"]}]
    }

    pev_1 = %{
      "name" => "TEST",
      "options" => ["1", "2"],
      "default_value" => "3",
      "required" => false,
      "description" => ""
    }

    pev_2 = %{
      "name" => "ENV_VAR",
      "options" => [],
      "default_value" => "",
      "required" => true,
      "description" => "asdf"
    }

    target_2 = %{
      "name" => "prod",
      "pipeline_path" => "./prod.yml",
      "parameter_env_vars" => %{"TEST" => pev_1, "ENV_VAR" => pev_2}
    }

    target_3 = %{
      "name" => "canary",
      "pipeline_path" => "./canary.yml",
      "parameter_env_vars" => %{},
      "deployment_target" => "canary"
    }

    targets_defs = [target_1, target_2, target_3]

    start_supervised!(SSupervisor)
    start_supervised!(STSupervisor)
    start_supervised!(TTSupervisor)

    {:ok, %{project_id: dpl.project_id, switch_def: switch_def, targets_defs: targets_defs}}
  end

  test "server availability by calling version() rpc" do
    {:ok, channel} = GRPC.Stub.connect("localhost:50055")
    request = VersionRequest.new()
    response = channel |> Switch.Stub.version(request)
    assert {:ok, version_response} = response
    assert Map.get(version_response, :version) == Mix.Project.config()[:version]
  end

  test "create API retruns {:ok, switch_id} for valid params", ctx do
    a_t_o = [
      AutoTriggerCond.new(result: "passed", branch: ["mast.", "xyz"]),
      AutoTriggerCond.new(result: "failed", result_reason: "test", branch: ["123"])
    ]

    target_1 =
      %{name: "staging", pipeline_path: "./staging.yml", auto_trigger_on: a_t_o}
      |> Target.new()

    p_e_v = [ParamEnvVar.new(%{name: "Test", options: ["1", "2"], required: true})]

    target_2 =
      %{name: "prod", pipeline_path: "./prod.yml", parameter_env_vars: p_e_v}
      |> Target.new()

    target_3 =
      %{name: "canary", pipeline_path: "./canary.yml", deployment_target: "canary"}
      |> Target.new()

    targets = [target_1, target_2, target_3]

    create_request =
      %{
        pipeline_id: UUID.uuid4(),
        targets: targets,
        project_id: ctx.project_id,
        branch_name: "master"
      }
      |> CreateRequest.new()

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50055")
    assert {:ok, create_response} = channel |> Switch.Stub.create(create_request)
    assert %CreateResponse{switch_id: resp_id, response_status: status} = create_response
    assert %ResponseStatus{code: code(:OK), message: ""} == status
    assert {:ok, _} = UUID.info(resp_id)

    assert {:ok, target_1} = TargetQueries.get_by_id_and_name(resp_id, "staging")
    assert target_1.parameter_env_vars == %{}

    assert target_1.auto_trigger_on ==
             [
               %{
                 "result" => "passed",
                 "result_reason" => "",
                 "branch" => ["mast.", "xyz"],
                 "labels" => [],
                 "label_patterns" => []
               },
               %{
                 "result" => "failed",
                 "result_reason" => "test",
                 "branch" => ["123"],
                 "labels" => [],
                 "label_patterns" => []
               }
             ]

    assert {:ok, target_2} = TargetQueries.get_by_id_and_name(resp_id, "prod")

    assert target_2.parameter_env_vars ==
             %{
               "Test" => %{
                 "required" => true,
                 "name" => "Test",
                 "default_value" => "",
                 "description" => "",
                 "options" => ["1", "2"]
               }
             }

    assert target_2.auto_trigger_on == []

    assert {:ok, target_3} = TargetQueries.get_by_id_and_name(resp_id, "canary")
    assert target_3.parameter_env_vars == %{}
    assert target_3.auto_trigger_on == []
    assert target_3.deployment_target == "canary"
  end

  test "PipelineDone API retruns {:ok, message} for valid params", ctx do
    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    request = %{switch_id: switch.id, result: "passed"} |> PipelineDoneRequest.new()
    assert {:ok, channel} = GRPC.Stub.connect("localhost:50055")
    assert {:ok, ppl_done_response} = channel |> Switch.Stub.pipeline_done(request)

    expected_message = "Pipeline execution result received and processed."
    assert %PipelineDoneResponse{response_status: status} = ppl_done_response
    assert %ResponseStatus{code: code(:OK), message: expected_message} == status
  end

  test "Trigger API returns {:ok, message} for valid params", ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    request_token = UUID.uuid4()

    request =
      %{
        switch_id: switch.id,
        target_name: "prod",
        triggered_by: "user1",
        override: true,
        request_token: request_token,
        env_variables: [EnvVariable.new(name: "ENV_VAR", value: "123")]
      }
      |> TriggerRequest.new()

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50055")
    assert {:ok, trigger_response} = channel |> Switch.Stub.trigger(request)
    assert %TriggerResponse{response_status: status} = trigger_response
    ok_message = "Target trigger request recorded."
    assert %ResponseStatus{code: code(:OK), message: ok_message} == status

    {:ok, switch_trigger} = SwitchTriggerQueries.get_by_request_token(request_token)

    # STP processed

    args = [SwitchTriggerQueries, :get_by_id, [switch_trigger.id]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    # TTP processed

    args = [TargetTriggerQueries, :get_by_id_and_name, [switch_trigger.id, "prod"]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 6_000)
  end

  test "ListTriggerEvents API returns {:ok, page} for valid params", ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)

    SwitchQueries.update(switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    "12345" |> String.codepoints() |> Enum.map(fn ind -> trigger_targets(switch.id, ind) end)

    request =
      %{switch_id: switch.id, target_name: "prod", page: 2, page_size: 2}
      |> ListTriggerEventsRequest.new()

    assert {:ok, channel} = GRPC.Stub.connect("localhost:50055")
    assert {:ok, list_response} = channel |> Switch.Stub.list_trigger_events(request)

    assert %ListTriggerEventsResponse{response_status: status} = list_response
    assert %ResponseStatus{code: code(:OK), message: ""} == status
    assert list_response.page_number == 2
    assert list_response.page_size == 2
    assert list_response.total_entries == 5
    assert list_response.total_pages == 3
    assert trigger_events_correct(list_response.trigger_events, 2, ["3", "2"])
  end

  test "Describe API returns {:ok, message} for valid params", ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    assert {:ok, switch} = SwitchQueries.insert(ctx.switch_def)

    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(0), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(1), switch)
    assert {:ok, _target} = TargetQueries.insert(ctx.targets_defs |> Enum.at(2), switch)

    SwitchQueries.update(switch, %{"ppl_done" => true, "ppl_result" => "passed"})

    trigger_targets(switch.id, "1")

    request = %{switch_id: switch.id, events_per_target: 5} |> DescribeRequest.new()
    assert {:ok, channel} = GRPC.Stub.connect("localhost:50055")
    assert {:ok, describe_response} = channel |> Switch.Stub.describe(request)

    assert %DescribeResponse{response_status: status} = describe_response
    assert %ResponseStatus{code: code(:OK), message: ""} == status
    assert describe_response.pipeline_done == true
    assert describe_response.pipeline_result == "passed"
    assert describe_response.ppl_id == switch.ppl_id
    assert describe_response.switch_id == switch.id
    assert targets_description_valid(describe_response.targets, 5, ["1"])
  end

  defp trigger_targets(switch_id, ind) do
    params = form_switch_trigger_params(switch_id, UUID.uuid4(), ["prod", "staging"], ind)
    id = params |> Map.get("id")

    STSupervisor.start_switch_trigger_process(id, params)

    # STP processed

    args = [SwitchTriggerQueries, :get_by_id, [id]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    # Both TTPs processed

    args = [TargetTriggerQueries, :get_by_id_and_name, [id, "staging"]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)

    args = [TargetTriggerQueries, :get_by_id_and_name, [id, "prod"]]
    Helpers.assert_finished_for_less_than(Helpers, :entity_processed?, args, 3_000)
  end

  defp form_switch_trigger_params(switch_id, request_token, target_names, ind) do
    %{
      "id" => UUID.uuid4(),
      "switch_id" => switch_id,
      "request_token" => request_token,
      "target_names" => target_names,
      "triggered_by" => "user_" <> ind,
      "triggered_at" => DateTime.utc_now(),
      "auto_triggered" => false,
      "override" => false,
      "processed" => false,
      "env_vars_for_target" => %{
        "prod" => [%{name: "TEST", value: "1"}, %{name: "NOT_PREDEFINED", value: "something"}]
      }
    }
  end

  defp targets_description_valid(targets, triggers_no, names) when is_list(targets) do
    targets
    |> Enum.map(fn target ->
      assert %TargetDescription{} = target
      assert target.name in ["prod", "staging", "canary"]
      assert target.pipeline_path in ["./prod.yml", "./stg.yml", "./canary.yml"]

      cond do
        target.name == "staging" ->
          assert target.auto_trigger_on == [
                   %AutoTriggerCond{
                     result: "passed",
                     result_reason: "",
                     branch: ["mast.", "xyz"],
                     labels: [],
                     label_patterns: []
                   }
                 ]

          assert target.parameter_env_vars == []
          assert is_nil(Map.get(target, :dt_description))

        target.name == "prod" ->
          assert target.auto_trigger_on == []

          p_e_v_1 =
            %{name: "TEST", options: ["1", "2"], default_value: "3"}
            |> Proto.deep_new!(ParamEnvVar)

          p_e_v_2 =
            %{name: "ENV_VAR", description: "asdf", required: true}
            |> Proto.deep_new!(ParamEnvVar)

          assert target.parameter_env_vars |> Enum.member?(p_e_v_1)
          assert target.parameter_env_vars |> Enum.member?(p_e_v_2)
          assert is_nil(Map.get(target, :dt_description))

        target.name == "canary" ->
          assert target.auto_trigger_on == []
          assert target.parameter_env_vars == []
          refute is_nil(Map.get(target, :dt_description))
          assert target.dt_description.target_name == "canary"
      end

      assert trigger_events_correct(target.trigger_events, triggers_no, names)
    end)

    true
  end

  defp targets_description_valid(_, _, _), do: false

  defp trigger_events_correct(triggers, triggers_no, names) when is_list(triggers) do
    assert length(triggers) <= triggers_no

    triggers
    |> Enum.with_index()
    |> Enum.map(fn {trigger, ind} ->
      assert %TriggerEvent{} = trigger
      assert trigger.auto_triggered == false
      assert trigger.error_response == ""
      assert trigger.override == false
      assert trigger.processed == true
      assert trigger.processing_result == :PASSED
      assert %Timestamp{} = trigger.triggered_at
      assert %Timestamp{} = trigger.scheduled_at
      assert {:ok, _} = UUID.info(trigger.scheduled_pipeline_id)
      assert trigger.target_name in ["prod", "staging"]

      if trigger.target_name == "prod" do
        assert trigger.env_variables ==
                 [
                   %EnvVariable{name: "TEST", value: "1"},
                   %EnvVariable{name: "NOT_PREDEFINED", value: "something"}
                 ]
      else
        assert trigger.env_variables == []
      end

      assert trigger.triggered_by == "user_" <> Enum.at(names, ind)
    end)

    true
  end

  defp trigger_events_correct(_, _, _), do: false

  defp code(value), do: value

  defp use_test_plumber_service(),
    do: Application.put_env(:gofer, :plumber_grpc_url, "localhost:#{inspect(@grpc_port)}")

  defp test_plumber_service_schedule_response(value),
    do: Application.put_env(:gofer, :test_plumber_service_schedule_response, value)
end
