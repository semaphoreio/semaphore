defmodule Gofer.TargetTrigger.Engine.TargetTriggerProcess.Test do
  use ExUnit.Case

  alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries
  alias Gofer.TargetTrigger.Engine.TargetTriggerProcess, as: TTP

  @grpc_port 50057

  setup_all do
    GRPC.Server.start(Test.MockPlumberService, @grpc_port)

    on_exit(fn ->
      GRPC.Server.stop(Test.MockPlumberService)
    end)

    {:ok, %{}}
  end

  setup do
    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table deployments cascade;")

    assert {:ok, _} = Ecto.Adapters.SQL.query(Gofer.EctoRepo, "truncate table switches cascade;")

    assert {:ok, switch} =
             SwitchQueries.insert(%{
               "id" => UUID.uuid4(),
               "ppl_id" => UUID.uuid4(),
               "git_ref_type" => "branch",
               "label" => "master",
               "prev_ppl_artefact_ids" => [],
               "branch_name" => "master"
             })

    request = %{"name" => "stg", "pipeline_path" => "./stg.yml"}
    assert {:ok, _target_1} = TargetQueries.insert(request, switch)

    request = %{"name" => "stg-2", "pipeline_path" => "./stg-2.yml"}
    assert {:ok, _target_2} = TargetQueries.insert(request, switch)

    request = %{"name" => "prod", "pipeline_path" => "./prod.yml"}
    assert {:ok, _target_3} = TargetQueries.insert(request, switch)

    sw_tg = %{
      "switch_id" => switch.id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg", "prod"],
      "request_token" => "asdf",
      "id" => UUID.uuid4(),
      "processed" => true
    }

    assert {:ok, switch_trigger} = SwitchTriggerQueries.insert(sw_tg)

    params = %{
      "switch_id" => switch.id,
      "switch_trigger_id" => switch_trigger.id,
      "target_name" => "stg"
    }

    assert {:ok, targ_tg_stg} = TargetTriggerQueries.insert(params)

    params = %{
      "switch_id" => switch.id,
      "switch_trigger_id" => switch_trigger.id,
      "target_name" => "prod"
    }

    assert {:ok, targ_tg_prod} = TargetTriggerQueries.insert(params)

    deployment_params = %{
      "name" => "staging",
      "organization_id" => UUID.uuid4(),
      "project_id" => UUID.uuid4(),
      "unique_token" => UUID.uuid4(),
      "created_by" => UUID.uuid4(),
      "updated_by" => UUID.uuid4(),
      "subject_rules" => [%{"type" => "USER", "subject_id" => UUID.uuid4()}],
      "object_rules" => [%{"type" => "BRANCH", "match_mode" => "EXACT", "pattern" => "master"}]
    }

    assert {:ok, deployment} = DeploymentQueries.create(deployment_params, :no_secret_params)

    assert {:ok, deployment} =
             DeploymentQueries.pass_syncing(deployment, %{secret_id: "123", secret_name: "456"})

    assert {:ok, deployment_trigger} = DeploymentTriggerQueries.create(switch, deployment, sw_tg)

    assert {:ok, deployment_trigger} =
             DeploymentTriggerQueries.transition_to(deployment_trigger, :STARTING)

    {:ok,
     %{
       switch_trigger: switch_trigger,
       targ_tg_stg: targ_tg_stg,
       targ_tg_prod: targ_tg_prod,
       deployment: deployment,
       deployment_trigger: deployment_trigger
     }}
  end

  test "can not start two TTPs for same switch_trigger_id and target_name", ctx do
    params = {ctx.switch_trigger.id, "stg"}

    assert {:ok, pid} = TTP.start_link(params)
    assert {:error, {:already_started, pid_2}} = TTP.start_link(params)
    assert pid == pid_2
  end

  test "TTP exits gracefully when there is no target_trigger in db" do
    state = %{switch_trigger_id: UUID.uuid4(), target_name: "non-existing"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)
  end

  test "TTP exits gracefully when target_trigger was already processed", ctx do
    assert {:ok, targ_tg_stg} =
             TargetTriggerQueries.update(ctx.targ_tg_stg, %{"processed" => true})

    assert true == targ_tg_stg.processed

    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)
  end

  test "TTP exits with \"Deadline reached\" even if there are older unprocessed triggers", ctx do
    previous_ttl = Application.get_env(:gofer, :target_trigger_ttl_ms)
    Application.put_env(:gofer, :target_trigger_ttl_ms, 50)

    on_exit(fn ->
      Application.put_env(:gofer, :target_trigger_ttl_ms, previous_ttl)
    end)

    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    request = %{
      "switch_id" => ctx.switch_trigger.switch_id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg"],
      "request_token" => "qwerty",
      "id" => UUID.uuid4(),
      "processed" => true
    }

    assert {:ok, new_sw_tg} = SwitchTriggerQueries.insert(request)

    params = %{
      "switch_id" => new_sw_tg.switch_id,
      "switch_trigger_id" => new_sw_tg.id,
      "target_name" => "stg"
    }

    assert {:ok, _new_targ_tg} = TargetTriggerQueries.insert(params)

    :timer.sleep(100)

    # second one does not wait for first but is canceld because of deadline
    state = %{switch_trigger_id: new_sw_tg.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} = TargetTriggerQueries.get_by_id_and_name(new_sw_tg.id, "stg")
    assert target_trigger.processed == true
    assert target_trigger.processing_result == "failed"
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt
    assert target_trigger.error_response == "Deadline reached"

    # first one also terminates because deadline is reached
    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert target_trigger.processed == true
    assert target_trigger.processing_result == "failed"
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt
    assert target_trigger.error_response == "Deadline reached"
  end

  test "TTP retrys with backoff when there is unprocessed older target trigger for same target",
       ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    request = %{
      "switch_id" => ctx.switch_trigger.switch_id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg"],
      "request_token" => "qwerty",
      "id" => UUID.uuid4(),
      "processed" => true
    }

    assert {:ok, new_sw_tg} = SwitchTriggerQueries.insert(request)

    params = %{
      "switch_id" => new_sw_tg.switch_id,
      "switch_trigger_id" => new_sw_tg.id,
      "target_name" => "stg"
    }

    assert {:ok, _new_targ_tg} = TargetTriggerQueries.insert(params)

    # second one waits for first
    state = %{switch_trigger_id: new_sw_tg.id, target_name: "stg"}
    assert {:noreply, resp_state} = TTP.handle_info(:schedule_pipeline, state)
    assert %{switch_trigger_id: new_sw_tg.id, target_name: "stg"} == resp_state
    assert_receive(:schedule_pipeline, 500, "Processing TargetTrigger was not rescheduled.")
    assert {:ok, new_targ_tg} = TargetTriggerQueries.get_by_id_and_name(new_sw_tg.id, "stg")
    assert new_targ_tg.processed == false

    # first is processed
    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert {:ok, _} = UUID.info(target_trigger.scheduled_ppl_id)
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt

    # second is processed
    state = %{switch_trigger_id: new_sw_tg.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} = TargetTriggerQueries.get_by_id_and_name(new_sw_tg.id, "stg")
    assert {:ok, _} = UUID.info(target_trigger.scheduled_ppl_id)
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt
  end

  test "TTP retrys with backoff when there is unprocessed older switch trigger for same target",
       ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    request = %{
      "switch_id" => ctx.switch_trigger.switch_id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg-2", "prod"],
      "request_token" => "qwerty",
      "id" => UUID.uuid4(),
      "processed" => false
    }

    assert {:ok, older_sw_tg} = SwitchTriggerQueries.insert(request)

    request = %{
      "switch_id" => older_sw_tg.switch_id,
      "triggered_by" => "user1",
      "triggered_at" => DateTime.utc_now(),
      "target_names" => ["stg-2"],
      "request_token" => "uiop",
      "id" => UUID.uuid4(),
      "processed" => true
    }

    assert {:ok, new_sw_tg} = SwitchTriggerQueries.insert(request)

    params = %{
      "switch_id" => new_sw_tg.switch_id,
      "switch_trigger_id" => new_sw_tg.id,
      "target_name" => "stg-2"
    }

    assert {:ok, _new_targ_tg} = TargetTriggerQueries.insert(params)

    # second one waits for first
    state = %{switch_trigger_id: new_sw_tg.id, target_name: "stg-2"}
    assert {:noreply, resp_state} = TTP.handle_info(:schedule_pipeline, state)
    assert %{switch_trigger_id: new_sw_tg.id, target_name: "stg-2"} == resp_state
    assert_receive(:schedule_pipeline, 500, "Processing TargetTrigger was not rescheduled.")
    assert {:ok, new_targ_tg} = TargetTriggerQueries.get_by_id_and_name(new_sw_tg.id, "stg-2")
    assert new_targ_tg.processed == false

    # first is processed
    params = %{
      "switch_id" => older_sw_tg.switch_id,
      "switch_trigger_id" => older_sw_tg.id,
      "target_name" => "stg-2"
    }

    assert {:ok, _old_targ_tg} = TargetTriggerQueries.insert(params)

    assert {:ok, _updated_old_sw_tg} = SwitchTriggerQueries.mark_as_processed(older_sw_tg)

    state = %{switch_trigger_id: older_sw_tg.id, target_name: "stg-2"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(older_sw_tg.id, "stg-2")

    assert {:ok, _} = UUID.info(target_trigger.scheduled_ppl_id)
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt

    # second is processed
    state = %{switch_trigger_id: new_sw_tg.id, target_name: "stg-2"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} = TargetTriggerQueries.get_by_id_and_name(new_sw_tg.id, "stg-2")
    assert {:ok, _} = UUID.info(target_trigger.scheduled_ppl_id)
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt
  end

  test "TTP initiates pipeline scheduling and stores result in db  when given valid params",
       ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert {:ok, _} = UUID.info(target_trigger.scheduled_ppl_id)
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt
  end

  test "TTP updates deployment target trigger when given valid params", ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    start_supervised!(
      {Test.MockDynamicSupervisor,
       [
         name: Gofer.DeploymentTrigger.Engine.Supervisor,
         call_extractor: &(&1 |> Map.get(:id))
       ]}
    )

    {:ok, target} = TargetQueries.get_by_id_and_name(ctx.switch_trigger.switch_id, "stg")
    Gofer.EctoRepo.update!(Ecto.Changeset.change(target, %{deployment_target: "staging"}))

    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert {:ok, _} = UUID.info(target_trigger.scheduled_ppl_id)
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt

    assert deployment_trigger_id = ctx.deployment_trigger.id

    assert {:ok, [{^deployment_trigger_id, _pid}]} =
             Test.MockDynamicSupervisor.get_calls(Gofer.DeploymentTrigger.Engine.Supervisor)
  end

  test "TTP omits deployment target trigger when trigger does not exist", ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("valid")

    start_supervised!(
      {Test.MockDynamicSupervisor,
       [
         name: Gofer.DeploymentTrigger.Engine.Supervisor,
         call_extractor: &(&1 |> Map.get(:id))
       ]}
    )

    {:ok, target} = TargetQueries.get_by_id_and_name(ctx.switch_trigger.switch_id, "stg")
    Gofer.EctoRepo.update!(Ecto.Changeset.change(target, %{deployment_target: "staging"}))
    Gofer.EctoRepo.delete!(ctx.deployment)

    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert {:ok, _} = UUID.info(target_trigger.scheduled_ppl_id)
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt

    assert {:ok, []} =
             Test.MockDynamicSupervisor.get_calls(Gofer.DeploymentTrigger.Engine.Supervisor)
  end

  test "TTP stores error when plumber returns :BAD_PARAM error and gracefuly exits", ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("bad_param")

    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert target_trigger.processed == true
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt
    assert target_trigger.error_response == "Error"
  end

  test "TTP restarts when plumber client returns something other than :BAD_PARAM and time_to_live is not reached",
       ctx do
    use_test_plumber_service()
    test_plumber_service_schedule_response("timeout")

    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :restart, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert target_trigger.processed == false
    assert target_trigger.scheduled_at == nil
    assert target_trigger.error_response == nil
  end

  test "TTP exits and storres \"Deadline reached\" error in db when time_to_live is reached",
       ctx do
    previous_ttl = Application.get_env(:gofer, :target_trigger_ttl_ms)
    Application.put_env(:gofer, :target_trigger_ttl_ms, 50)

    on_exit(fn ->
      Application.put_env(:gofer, :target_trigger_ttl_ms, previous_ttl)
    end)

    use_test_plumber_service()
    test_plumber_service_schedule_response("timeout")

    :timer.sleep(100)

    state = %{switch_trigger_id: ctx.switch_trigger.id, target_name: "stg"}
    assert {:stop, :normal, state} == TTP.handle_info(:schedule_pipeline, state)

    assert {:ok, target_trigger} =
             TargetTriggerQueries.get_by_id_and_name(ctx.switch_trigger.id, "stg")

    assert target_trigger.processed == true
    assert DateTime.compare(target_trigger.scheduled_at, DateTime.utc_now()) == :lt
    assert target_trigger.error_response == "Deadline reached"
  end

  defp use_test_plumber_service(),
    do: Application.put_env(:gofer, :plumber_grpc_url, "localhost:#{inspect(@grpc_port)}")

  defp test_plumber_service_schedule_response(value),
    do: Application.put_env(:gofer, :test_plumber_service_schedule_response, value)
end
