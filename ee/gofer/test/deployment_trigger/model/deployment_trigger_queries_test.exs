defmodule Gofer.DeploymentTrigger.Model.DeploymentTriggerQueriesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries, as: TriggerQueries
  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger, as: Trigger

  alias Gofer.TargetTrigger.Model.TargetTrigger
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch
  alias Gofer.EctoRepo

  setup_all [
    :prepare_data,
    :prepare_switch_trigger_params,
    :setup_deployment,
    :setup_switch
  ]

  setup [
    :truncate_database
  ]

  describe "list_by_target_id/1" do
    test "when target does not exist then return empty list" do
      assert [] = TriggerQueries.list_by_target_id(UUID.uuid4())
    end

    test "when target has no triggers then return empty list", ctx do
      assert [] = TriggerQueries.list_by_target_id(ctx.deployment.id)
    end

    test "when target has some triggers then return n latest triggers", ctx do
      all_triggers =
        for _ <- 1..25 do
          {:ok, [trigger: trigger]} =
            insert_trigger(ctx, %{
              switch_trigger_id: UUID.uuid4(),
              request_token: UUID.uuid4(),
              pipeline_id: UUID.uuid4(),
              scheduled_at: DateTime.utc_now(),
              result: "passed",
              state: :DONE
            })

          trigger
        end

      lastest_trigger_ids =
        all_triggers
        |> Enum.sort_by(& &1.triggered_at, DateTime)
        |> Enum.take(10)
        |> Enum.map(& &1.id)

      assert last_triggers = TriggerQueries.list_by_target_id(ctx.deployment.id)
      assert Enum.all?(last_triggers, &match?(%Trigger{}, &1))
      assert Enum.all?(last_triggers, &match?(%Switch{}, &1.switch))
      assert Enum.all?(last_triggers, &Enum.member?(lastest_trigger_ids, &1.id))
      assert Enum.count(last_triggers) == 10
    end
  end

  describe "find_by_id/1" do
    setup [:insert_trigger]

    test "when trigger exists then return it", %{trigger: trigger} do
      assert %Trigger{id: id, switch_trigger_id: sti, target_name: tn} = trigger

      assert {:ok, %Trigger{switch_trigger_id: ^sti, target_name: ^tn}} =
               TriggerQueries.find_by_id(id)
    end

    test "when deployment doesn't exist then return error" do
      assert {:error, :not_found} = TriggerQueries.find_by_id(UUID.uuid4())
    end
  end

  describe "find_by_request_token/1" do
    setup [:insert_trigger]

    test "when trigger exists then return it", ctx do
      assert {:ok, %Trigger{id: trigger_id}} =
               TriggerQueries.find_by_request_token(ctx.request_token)

      assert ^trigger_id = ctx.trigger.id
    end

    test "when deployment doesn't exist then return error" do
      assert {:error, :not_found} = TriggerQueries.find_by_request_token(UUID.uuid4())
    end
  end

  describe "find_by_switch_trigger_and_target/2" do
    setup [:insert_trigger]

    test "when deployment exists then return it", %{trigger: trigger} do
      assert %Trigger{id: id, switch_trigger_id: sti, target_name: tn} = trigger
      assert {:ok, %Trigger{id: ^id}} = TriggerQueries.find_by_switch_trigger_and_target(sti, tn)
    end

    test "when deployment exists then preload deployment", %{trigger: trigger} do
      assert %Trigger{switch_trigger_id: sti, target_name: tn} = trigger

      assert {:ok, %Trigger{deployment: %Deployment{}}} =
               TriggerQueries.find_by_switch_trigger_and_target(sti, tn)
    end

    test "when deployment doesn't exist then return error", _ctx do
      assert {:error, :not_found} =
               TriggerQueries.find_by_switch_trigger_and_target(UUID.uuid4(), "target")
    end
  end

  describe "create/1" do
    test "when trigger already exists and request token is the same then return trigger", ctx do
      insert_trigger(ctx)

      assert {:ok, trigger = %Trigger{}} =
               TriggerQueries.create(ctx.switch, ctx.deployment, ctx.switch_trigger_params)

      assert trigger.deployment_id == ctx.deployment.id
      assert trigger.switch_trigger_id == ctx.switch_trigger_id
      assert trigger.target_name == ctx.target_name
      assert trigger.triggered_by == ctx.triggered_by
      assert trigger.triggered_at == ctx.triggered_at
    end

    test "when trigger already exists but request token is different then return error", ctx do
      insert_trigger(ctx, %{request_token: UUID.uuid4()})

      assert {:error, %Ecto.Changeset{errors: errors}} =
               TriggerQueries.create(ctx.switch, ctx.deployment, ctx.switch_trigger_params)

      assert [target_name: {"has already been taken", [{:constraint, :unique} | _]}] = errors
    end

    test "when deployment does not exist then return error", ctx do
      deployment = %Deployment{ctx.deployment | id: UUID.uuid4()}

      assert {:error, %Ecto.Changeset{errors: errors}} =
               TriggerQueries.create(ctx.switch, deployment, ctx.switch_trigger_params)

      assert [deployment_id: {"does not exist", _}] = errors
    end

    test "when mandatory params are missing then return error", ctx do
      assert {:error, %Ecto.Changeset{errors: [switch_trigger_id: {"can't be blank", _}]}} =
               TriggerQueries.create(
                 ctx.switch,
                 ctx.deployment,
                 Map.delete(
                   ctx.switch_trigger_params,
                   "id"
                 )
               )

      assert {:error, %Ecto.Changeset{errors: [target_name: {"can't be blank", _}]}} =
               TriggerQueries.create(
                 ctx.switch,
                 ctx.deployment,
                 Map.delete(
                   ctx.switch_trigger_params,
                   "target_names"
                 )
               )

      assert {:error, %Ecto.Changeset{errors: [triggered_by: {"can't be blank", _}]}} =
               TriggerQueries.create(
                 ctx.switch,
                 ctx.deployment,
                 Map.delete(
                   ctx.switch_trigger_params,
                   "triggered_by"
                 )
               )

      assert {:error, %Ecto.Changeset{errors: [triggered_at: {"can't be blank", _}]}} =
               TriggerQueries.create(
                 ctx.switch,
                 ctx.deployment,
                 Map.delete(
                   ctx.switch_trigger_params,
                   "triggered_at"
                 )
               )
    end

    test "when trigger is new then return it", ctx do
      assert {:ok, trigger = %Trigger{}} =
               TriggerQueries.create(ctx.switch, ctx.deployment, ctx.switch_trigger_params)

      assert trigger.deployment_id == ctx.deployment.id
      assert trigger.switch_trigger_id == ctx.switch_trigger_id
      assert trigger.target_name == ctx.target_name
      assert trigger.triggered_by == ctx.triggered_by
      assert trigger.triggered_at == ctx.triggered_at
    end

    test "when deployment has bookmarks then copies them", ctx do
      deployment = %{ctx.deployment | bookmark_parameter1: "boo", bookmark_parameter2: "foo"}

      switch_trigger_params = %{
        ctx.switch_trigger_params
        | "env_vars_for_target" => %{
            ctx.target_name => [
              %{"name" => "foo", "value" => "bar"}
            ]
          }
      }

      assert {:ok, trigger = %Trigger{}} =
               TriggerQueries.create(ctx.switch, deployment, switch_trigger_params)

      assert trigger.deployment_id == ctx.deployment.id
      assert trigger.switch_trigger_id == ctx.switch_trigger_id
      assert trigger.target_name == ctx.target_name
      assert trigger.triggered_by == ctx.triggered_by
      assert trigger.triggered_at == ctx.triggered_at

      refute trigger.parameter1
      assert trigger.parameter2 == "bar"
      refute trigger.parameter3
    end
  end

  describe "transition_to/2" do
    setup [:insert_trigger]

    test "when state is invalid then returns error", ctx do
      assert {:error, %Ecto.Changeset{errors: [state: {"is invalid", _}]}} =
               TriggerQueries.transition_to(ctx.trigger, :UNKNOWN)
    end

    test "when state is :DONE then raises error", ctx do
      assert_raise RuntimeError,
                   "Use finalize/2 to move trigger to :DONE state and set result",
                   fn ->
                     TriggerQueries.transition_to(ctx.trigger, :DONE)
                   end
    end

    test "when trigger doesn't exist then raises error", ctx do
      assert {:ok, %Trigger{}} = EctoRepo.delete(ctx.trigger)

      assert {:error, %Ecto.StaleEntryError{}} =
               TriggerQueries.transition_to(ctx.trigger, :TRIGGERING)
    end

    test "when state is valid then returns updated trigger", ctx do
      assert {:ok, %Trigger{state: :TRIGGERING}} =
               TriggerQueries.transition_to(ctx.trigger, :TRIGGERING)

      assert {:ok, %Trigger{state: :STARTING}} =
               TriggerQueries.transition_to(ctx.trigger, :STARTING)
    end
  end

  describe "finalize/2" do
    setup [
      :insert_trigger,
      :prepare_successful_target_trigger,
      :prepare_failed_target_trigger
    ]

    test "when trigger exists then moves it to :DONE state", ctx do
      assert {:ok, %Trigger{state: :DONE}} =
               TriggerQueries.finalize(ctx.trigger, ctx.success_target_trigger)
    end

    test "when trigger doesn't exist then raises error", ctx do
      assert {:ok, %Trigger{}} = EctoRepo.delete(ctx.trigger)

      assert {:error, %Ecto.StaleEntryError{}} =
               TriggerQueries.finalize(ctx.trigger, ctx.success_target_trigger)
    end

    test "when trigger exists then copies result and reason from target trigger", ctx do
      pipeline_id = ctx.success_target_trigger.scheduled_ppl_id
      scheduled_at = ctx.success_target_trigger.scheduled_at

      assert {:ok,
              %Trigger{
                pipeline_id: ^pipeline_id,
                scheduled_at: ^scheduled_at,
                result: "passed",
                reason: nil
              }} = TriggerQueries.finalize(ctx.trigger, ctx.success_target_trigger)

      assert {:ok,
              %Trigger{
                pipeline_id: nil,
                scheduled_at: nil,
                result: "failed",
                reason: "Deadline reached"
              }} = TriggerQueries.finalize(ctx.trigger, ctx.failure_target_trigger)
    end
  end

  describe "scan_runnable/0" do
    test "when none are configured then return empty list", _ctx do
      assert length(TriggerQueries.scan_runnable(NaiveDateTime.utc_now(), 0, 5)) == 0
    end

    test "when some are configured then return list of deployments", ctx do
      for _ <- 1..6 do
        insert_trigger(ctx, %{
          switch_trigger_id: UUID.uuid4(),
          target_name: "target",
          state: :INITIALIZING,
          request_token: UUID.uuid4()
        })
      end

      for _ <- 1..7 do
        insert_trigger(ctx, %{
          switch_trigger_id: UUID.uuid4(),
          target_name: "target",
          state: :INITIALIZING,
          request_token: UUID.uuid4()
        })
      end

      for _ <- 1..8 do
        insert_trigger(ctx, %{
          switch_trigger_id: UUID.uuid4(),
          target_name: "target",
          state: :INITIALIZING,
          request_token: UUID.uuid4()
        })
      end

      startup_time = NaiveDateTime.utc_now()
      batch_size = 5

      assert length(TriggerQueries.scan_runnable(startup_time, 0, batch_size)) == 5
      assert length(TriggerQueries.scan_runnable(startup_time, 1, batch_size)) == 5
      assert length(TriggerQueries.scan_runnable(startup_time, 2, batch_size)) == 5
      assert length(TriggerQueries.scan_runnable(startup_time, 3, batch_size)) == 5
      assert length(TriggerQueries.scan_runnable(startup_time, 4, batch_size)) == 1
      assert length(TriggerQueries.scan_runnable(startup_time, 5, batch_size)) == 0
    end
  end

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployment_triggers CASCADE;")
    :ok
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

  defp setup_deployment(context) do
    on_exit(fn ->
      EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")
    end)

    {:ok,
     deployment:
       EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Deployment",
         description: "Deployment target",
         organization_id: context.organization_id,
         project_id: context.project_id,
         unique_token: context.unique_token,
         created_by: context.user_id,
         updated_by: context.user_id,
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

  defp setup_switch(context) do
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

  defp insert_trigger(context, extra \\ %{}) do
    defaults = %{
      deployment_id: context.deployment.id,
      triggered_by: context.triggered_by,
      triggered_at: context.triggered_at,
      switch_trigger_id: context.switch_trigger_id,
      target_name: context.target_name,
      switch_id: context.switch_id,
      git_ref_type: context.switch.git_ref_type,
      git_ref_label: context.switch.label,
      request_token: context.request_token,
      switch_trigger_params: context.switch_trigger_params
    }

    {:ok, trigger: EctoRepo.insert!(struct!(Trigger, Map.merge(defaults, extra)))}
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

  defp prepare_successful_target_trigger(_context) do
    {:ok,
     success_target_trigger: %TargetTrigger{
       scheduled_at: DateTime.utc_now(),
       scheduled_ppl_id: UUID.uuid4(),
       processing_result: "passed",
       error_response: nil
     }}
  end

  defp prepare_failed_target_trigger(_context) do
    {:ok,
     failure_target_trigger: %TargetTrigger{
       processing_result: "failed",
       error_response: "Deadline reached"
     }}
  end
end
