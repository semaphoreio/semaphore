defmodule Gofer.DeploymentTrigger.Engine.WorkerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries, as: Queries
  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger, as: Trigger

  alias Gofer.TargetTrigger.Model.TargetTrigger
  alias Gofer.DeploymentTrigger.Engine.Worker
  alias Gofer.DeploymentTrigger.Engine
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch

  alias Gofer.EctoRepo

  setup_all [
    :prepare_data,
    :prepare_switch_trigger_params
  ]

  describe "Supervisor.start_worker/3" do
    setup [
      :truncate_all_tables,
      :insert_deployment,
      :insert_switch,
      :mock_engine_supervisor
    ]

    test "when provided arguments are correct then starts worker", ctx do
      assert request_token = ctx.switch_trigger_params["request_token"]
      assert {:error, :not_found} = Queries.find_by_request_token(request_token)

      assert {:ok, _pid} =
               Engine.Supervisor.start_worker(
                 ctx.switch,
                 ctx.deployment,
                 ctx.switch_trigger_params
               )

      assert {:ok, [{^request_token, _pid}]} =
               Test.MockDynamicSupervisor.get_calls(Engine.Supervisor)
    end

    test "when provided arguements are invalid then exits immediately", ctx do
      assert request_token = ctx.switch_trigger_params["request_token"]
      assert {:error, :not_found} = Queries.find_by_request_token(request_token)

      assert {:error, changeset = %Ecto.Changeset{}} =
               Queries.create(ctx.switch, ctx.deployment, %{
                 ctx.switch_trigger_params
                 | "triggered_by" => nil
               })

      Test.MockDynamicSupervisor.set_response(Engine.Supervisor, {:error, changeset})

      assert {:error, %Ecto.Changeset{errors: [triggered_by: {"can't be blank", _}]}} =
               Engine.Supervisor.start_worker(ctx.switch, ctx.deployment, %{
                 ctx.switch_trigger_params
                 | "triggered_by" => nil
               })

      assert {:ok, [{^request_token, _pid}]} =
               Test.MockDynamicSupervisor.get_calls(Engine.Supervisor)
    end

    test "when trigger already exists then starts worker using existing trigger", ctx do
      {:ok, trigger: trigger = %Trigger{}} = insert_trigger(ctx)
      assert request_token = trigger.request_token
      assert {:ok, _trigger} = Queries.find_by_request_token(request_token)

      assert {:ok, _pid} =
               Engine.Supervisor.start_worker(
                 ctx.switch,
                 ctx.deployment,
                 ctx.switch_trigger_params
               )

      assert {:ok, [{^request_token, _pid}]} =
               Test.MockDynamicSupervisor.get_calls(Engine.Supervisor)
    end
  end

  describe "Supervisor.start_worker/1" do
    setup [
      :truncate_all_tables,
      :insert_deployment,
      :insert_switch,
      :insert_trigger,
      :mock_engine_supervisor
    ]

    test "when trigger is passed directly then starts worker", ctx do
      assert {:ok, _pid} = Engine.Supervisor.start_worker(ctx.trigger)
      assert request_token = ctx.trigger.request_token

      assert {:ok, [{^request_token, _pid}]} =
               Test.MockDynamicSupervisor.get_calls(Engine.Supervisor)
    end

    test "when trigger is passed as ID then starts worker", ctx do
      assert {:ok, _pid} = Engine.Supervisor.start_worker(ctx.trigger)
      assert request_token = ctx.trigger.request_token

      assert {:ok, [{^request_token, _pid}]} =
               Test.MockDynamicSupervisor.get_calls(Engine.Supervisor)
    end

    test "when trigger is passed as random ID then starts worker" do
      assert {:error, :not_found} = Engine.Supervisor.start_worker(UUID.uuid4())
    end

    test "when trigger is passed as switch and target then starts worker", ctx do
      assert {:ok, _pid} =
               Engine.Supervisor.start_worker(
                 ctx.trigger.switch_trigger_id,
                 ctx.trigger.target_name
               )

      assert request_token = ctx.trigger.request_token

      assert {:ok, [{^request_token, _pid}]} =
               Test.MockDynamicSupervisor.get_calls(Engine.Supervisor)
    end

    test "when trigger is passed as random switch or target then returns error", ctx do
      assert {:error, :not_found} =
               Engine.Supervisor.start_worker(
                 ctx.trigger.switch_trigger_id,
                 "random_target_name"
               )
    end
  end

  describe "start_link/1" do
    setup [
      :truncate_all_tables,
      :insert_deployment,
      :insert_switch,
      :insert_trigger
    ]

    test "when there are no errors then it is not restarted", ctx do
      :erlang.process_flag(:trap_exit, true)

      assert {:ok, pid} = Worker.start_link(%Trigger{ctx.trigger | state: :DONE})
      assert_receive {:EXIT, ^pid, :normal}, 1_000
    end

    test "when there are known errors then worker is stopped", ctx do
      :erlang.process_flag(:trap_exit, true)

      assert {:ok, pid} = Worker.start_link(%Trigger{ctx.trigger | state: :UNKNOWN})
      assert_receive {:EXIT, ^pid, :normal}, 5_000
    end

    test "when there are unknown errors then worker is restarted", ctx do
      :erlang.process_flag(:trap_exit, true)

      assert {:ok, pid} =
               Worker.start_link(%Trigger{
                 ctx.trigger
                 | state: :TRIGGERING,
                   switch_trigger_params: nil
               })

      assert_receive {:EXIT, ^pid, reason}, 5_000
      refute reason in [:normal, :shutdown]
      refute match?({:shutdown, _}, reason)
    end
  end

  describe "handle_info/2 when state = :INITIALIZING " do
    setup [
      :truncate_all_tables,
      :insert_deployment,
      :insert_switch,
      :insert_trigger
    ]

    test "and params are valid then transitions to :TRIGGERING state and continues", ctx do
      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :INITIALIZING})

      assert %Trigger{state: :TRIGGERING} = EctoRepo.get(Trigger, ctx.trigger.id)
      assert_received :run
    end

    test "and deployment is not found then stops and doesn't retry", ctx do
      assert {:stop, :normal, %Trigger{id: trigger_id}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :INITIALIZING,
                   deployment_id: UUID.uuid4()
               })

      assert %Trigger{state: :DONE, result: "failed", reason: "missing_deployment"} =
               EctoRepo.get(Trigger, trigger_id)

      refute_received :run
    end

    test "and switch is not found then stops and doesn't retry", ctx do
      assert {:stop, :normal, %Trigger{id: trigger_id}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :INITIALIZING,
                   switch_id: UUID.uuid4()
               })

      assert %Trigger{state: :DONE, result: "failed", reason: "missing_switch"} =
               EctoRepo.get(Trigger, trigger_id)

      refute_received :run
    end

    test "and deployment is syncing then stops and doesn't retry", ctx do
      ctx.deployment |> Ecto.Changeset.change(%{state: :SYNCING}) |> EctoRepo.update!()

      assert {:stop, :normal, %Trigger{id: trigger_id}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :INITIALIZING})

      assert %Trigger{state: :DONE, result: "failed", reason: "syncing_target"} =
               EctoRepo.get(Trigger, trigger_id)

      refute_received :run
    end

    test "and deployment is forbidden then stops and doesn't retry", ctx do
      assert {:stop, :normal, %Trigger{id: trigger_id}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :INITIALIZING,
                   triggered_by: UUID.uuid4()
               })

      assert %Trigger{state: :DONE, result: "failed", reason: "banned_subject"} =
               EctoRepo.get(Trigger, trigger_id)

      refute_received :run
    end

    test "and params are invalid then retries the trigger", ctx do
      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :INITIALIZING,
                   triggered_at: nil
               })

      assert %Trigger{updated_at: updated_at} = EctoRepo.get(Trigger, ctx.trigger.id)

      assert ^updated_at = ctx.trigger.updated_at
      assert_received :run
    end

    test "and deadline was reached then fails the trigger", ctx do
      now = NaiveDateTime.utc_now()
      updated_at = NaiveDateTime.add(now, -90)

      assert {:stop, :normal, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :INITIALIZING,
                   updated_at: updated_at
               })

      assert %Trigger{
               state: :DONE,
               result: "failed",
               reason: "deadline_reached",
               updated_at: updated_at
             } = EctoRepo.get(Trigger, ctx.trigger.id)

      refute_received :run
      assert NaiveDateTime.compare(updated_at, now) == :gt
    end
  end

  describe "handle_info/2 when state = :TRIGGERING" do
    setup [
      :truncate_all_tables,
      :insert_deployment,
      :insert_switch,
      :insert_trigger
    ]

    test "then attempts to start switch trigger and transition to :STARTING state",
         ctx do
      alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
      start_supervised!({Test.MockDynamicSupervisor, [name: STSupervisor]})

      %Trigger{switch_trigger_id: sti, switch_trigger_params: stp} = ctx.trigger

      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :TRIGGERING})

      assert {:error, {:already_started, _}} = STSupervisor.start_switch_trigger_process(sti, stp)
      assert %Trigger{state: :STARTING} = EctoRepo.get(Trigger, ctx.trigger.id)
    end

    test "and switch trigger already runs then transition to :STARTING state",
         ctx do
      alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
      start_supervised!({Test.MockDynamicSupervisor, [name: STSupervisor]})

      %Trigger{switch_trigger_id: sti, switch_trigger_params: stp} = ctx.trigger
      STSupervisor.start_switch_trigger_process(sti, stp)

      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :TRIGGERING})

      assert %Trigger{state: :STARTING} = EctoRepo.get(Trigger, ctx.trigger.id)
    end

    test "and supervisor returns error then retries the trigger", ctx do
      alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor

      start_supervised!(
        {Test.MockDynamicSupervisor,
         [
           name: STSupervisor,
           mock_response: {:error, :max_children}
         ]}
      )

      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :TRIGGERING
               })

      assert %Trigger{updated_at: updated_at} = EctoRepo.get(Trigger, ctx.trigger.id)
      assert ^updated_at = ctx.trigger.updated_at
      assert_received :run
    end

    test "and trigger has been removed then stops the worker", ctx do
      alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
      start_supervised!({Test.MockDynamicSupervisor, [name: STSupervisor]})

      assert {:ok, %Deployment{}} = EctoRepo.delete(ctx.deployment)

      assert {:stop, :normal, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :TRIGGERING})
    end

    test "and params are invalid then retries the trigger", ctx do
      alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor, as: STSupervisor
      start_supervised!({Test.MockDynamicSupervisor, [name: STSupervisor]})

      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :TRIGGERING,
                   switch_trigger_params: nil
               })

      assert %Trigger{updated_at: updated_at} = EctoRepo.get(Trigger, ctx.trigger.id)
      assert ^updated_at = ctx.trigger.updated_at
      assert_received :run
    end

    test "and deadline was reached then fails the trigger", ctx do
      now = NaiveDateTime.utc_now()
      updated_at = NaiveDateTime.add(now, -90)

      assert {:stop, :normal, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :TRIGGERING,
                   updated_at: updated_at
               })

      assert %Trigger{
               state: :DONE,
               result: "failed",
               reason: "deadline_reached",
               updated_at: updated_at
             } = EctoRepo.get(Trigger, ctx.trigger.id)

      refute_received :run
      assert NaiveDateTime.compare(updated_at, now) == :gt
    end
  end

  describe "handle_info/2 when state = :STARTING" do
    setup [
      :truncate_all_tables,
      :insert_deployment,
      :insert_switch,
      :insert_trigger
    ]

    test "and target trigger is processed then transitions to :DONE state", ctx do
      pipeline_id = UUID.uuid4()

      insert_target_trigger(ctx, %{
        scheduled_ppl_id: pipeline_id,
        processed: true,
        processing_result: "passed"
      })

      assert {:stop, :normal, %Trigger{pipeline_id: ^pipeline_id, state: :DONE, result: "passed"}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :STARTING})

      truncate_tables(~w(target_triggers switch_triggers))

      insert_target_trigger(ctx, %{
        processed: true,
        processing_result: "failed",
        error_response: "Deadline reached"
      })

      assert {:stop, :normal,
              %Trigger{
                state: :DONE,
                pipeline_id: nil,
                result: "failed",
                reason: "Deadline reached"
              }} = Worker.handle_info(:run, %Trigger{ctx.trigger | state: :STARTING})
    end

    test "and target trigger is unprocessed then retries the trigger", ctx do
      insert_target_trigger(ctx, %{processed: false})

      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :STARTING})

      assert %Trigger{updated_at: updated_at} = EctoRepo.get(Trigger, ctx.trigger.id)
      assert ^updated_at = ctx.trigger.updated_at
      assert_received :run
    end

    test "and target trigger is missing then retries the trigger", ctx do
      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :STARTING})

      assert %Trigger{updated_at: updated_at} = EctoRepo.get(Trigger, ctx.trigger.id)
      assert ^updated_at = ctx.trigger.updated_at
      assert_received :run
    end

    test "and deployment target trigger is missing then stops worker", ctx do
      insert_target_trigger(ctx, %{
        scheduled_ppl_id: UUID.uuid4(),
        processed: true,
        processing_result: "passed"
      })

      assert {:ok, %Deployment{}} = EctoRepo.delete(ctx.deployment)

      assert {:stop, :normal, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :STARTING})
    end

    test "and payload is faulty then retries the trigger", ctx do
      assert {:noreply, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :STARTING,
                   deployment_id: nil
               })

      assert %Trigger{updated_at: updated_at} = EctoRepo.get(Trigger, ctx.trigger.id)
      assert ^updated_at = ctx.trigger.updated_at
      assert_received :run
    end

    test "and deadline was reached then fails the trigger", ctx do
      now = NaiveDateTime.utc_now()
      updated_at = NaiveDateTime.add(now, -90)

      assert {:stop, :normal, %Trigger{}} =
               Worker.handle_info(:run, %Trigger{
                 ctx.trigger
                 | state: :STARTING,
                   updated_at: updated_at
               })

      assert %Trigger{
               state: :DONE,
               result: "failed",
               reason: "deadline_reached",
               updated_at: updated_at
             } = EctoRepo.get(Trigger, ctx.trigger.id)

      refute_received :run
      assert NaiveDateTime.compare(updated_at, now) == :gt
    end
  end

  describe "handle_info/2 when state = :DONE" do
    setup [
      :truncate_all_tables,
      :insert_deployment,
      :insert_switch,
      :insert_trigger
    ]

    test "then does nothing and stops the worker", ctx do
      assert {:stop, :normal, %Trigger{state: :DONE, result: "passed"}} =
               Worker.handle_info(:run, %Trigger{ctx.trigger | state: :DONE, result: "passed"})

      refute_received :run
    end
  end

  defp mock_engine_supervisor(_ctx) do
    start_supervised!(
      {Test.MockDynamicSupervisor,
       [
         name: Engine.Supervisor,
         call_extractor: fn
           {_s, _d, p} -> p["request_token"]
           trigger -> trigger.request_token
         end
       ]}
    )

    :ok
  end

  defp truncate_all_tables(_context) do
    truncate_tables(~w(
      deployment_triggers deployments
      target_triggers targets
      switch_triggers switches
    ))
  end

  defp truncate_tables(table_names) do
    for table_name <- table_names, do: truncate_table(table_name)
    :ok
  end

  defp truncate_table(table_name) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE #{table_name} CASCADE;")
  end

  defp prepare_data(_context) do
    {:ok,
     organization_id: UUID.uuid4(),
     project_id: UUID.uuid4(),
     user_id: UUID.uuid4(),
     unique_token: UUID.uuid4(),
     triggered_by: UUID.uuid4(),
     triggered_at: DateTime.utc_now(),
     switch_trigger_id: UUID.uuid4(),
     switch_id: UUID.uuid4(),
     target_name: "target",
     request_token: UUID.uuid4()}
  end

  defp prepare_switch_trigger_params(context) do
    {:ok,
     switch_trigger_params: %{
       "id" => context.switch_trigger_id,
       "switch_id" => context.switch_id,
       "request_token" => context.request_token,
       "target_names" => [context.target_name],
       "triggered_by" => context.triggered_by,
       "triggered_at" => context.triggered_at,
       "auto_triggered" => false,
       "override" => false,
       "env_vars_for_target" => %{},
       "processed" => false
     }}
  end

  defp insert_deployment(context) do
    deployment =
      %Deployment{}
      |> Deployment.changeset(%{
        name: "Deployment",
        organization_id: context.organization_id,
        project_id: context.project_id,
        unique_token: context.unique_token,
        created_by: context.user_id,
        updated_by: context.user_id,
        subject_rules: [%{type: :USER, subject_id: context.triggered_by}],
        object_rules: [%{type: :BRANCH, match_mode: :EXACT, pattern: "master"}]
      })
      |> Ecto.Changeset.put_change(:state, :FINISHED)
      |> Ecto.Changeset.put_change(:result, :SUCCESS)
      |> EctoRepo.insert!()

    {:ok, deployment: deployment}
  end

  defp insert_switch(context) do
    switch =
      %Switch{}
      |> Switch.changeset(%{
        id: context.switch_id,
        ppl_id: UUID.uuid4(),
        prev_ppl_artefact_ids: [UUID.uuid4()],
        branch_name: "master",
        label: "master",
        git_ref_type: "branch"
      })
      |> EctoRepo.insert!()

    {:ok, switch: switch}
  end

  defp insert_trigger(context) do
    trigger =
      %Trigger{}
      |> Trigger.changeset(%{
        deployment_id: context.deployment.id,
        switch_id: context.switch.id,
        git_ref_type: context.switch.git_ref_type,
        git_ref_label: context.switch.label,
        triggered_by: context.triggered_by,
        triggered_at: context.triggered_at,
        switch_trigger_id: context.switch_trigger_id,
        target_name: context.target_name,
        request_token: context.request_token,
        switch_trigger_params: context.switch_trigger_params
      })
      |> EctoRepo.insert!()

    {:ok, trigger: trigger}
  end

  defp insert_target_trigger(context, extra) do
    EctoRepo.insert!(%Gofer.SwitchTrigger.Model.SwitchTrigger{
      id: context.switch_trigger_id,
      switch_id: context.switch_id
    })

    target_trigger_defaults = %{
      switch_trigger_id: context.switch_trigger_id,
      target_name: context.target_name,
      switch_id: context.switch_id,
      processed: false
    }

    target_trigger =
      EctoRepo.insert!(struct!(TargetTrigger, Map.merge(target_trigger_defaults, extra)))

    {:ok, target_trigger: target_trigger}
  end
end
