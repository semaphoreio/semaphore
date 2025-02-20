defmodule Gofer.DeploymentTrigger.Model.MetricsQueriesTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Gofer.DeploymentTrigger.Model.MetricsQueries
  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch

  alias Gofer.EctoRepo

  setup [
    :truncate_database,
    :prepare_data,
    :prepare_switch_trigger_params,
    :setup_staging_example,
    :setup_production_example,
    :setup_switch
  ]

  test "count_used_targets/0 returns the correct number", ctx do
    insert_trigger(ctx, deployment_id: ctx.stg.id, target_name: "staging")
    assert MetricsQueries.count_used_targets() == 1

    insert_trigger(ctx, deployment_id: ctx.prod.id, target_name: "production")
    assert MetricsQueries.count_used_targets() == 2
  end

  test "count_stuck_triggers/0 returns the correct number", ctx do
    for state <- ~w(INITIALIZING TRIGGERING STARTING DONE)a do
      target_name = "staging_#{state |> Atom.to_string() |> String.downcase()}"
      insert_trigger(ctx, deployment_id: ctx.stg.id, target_name: target_name, state: state)
    end

    assert MetricsQueries.count_stuck_triggers() == 0

    for state <- ~w(INITIALIZING TRIGGERING STARTING DONE)a do
      target_name = "old_staging_#{state |> Atom.to_string() |> String.downcase()}"

      insert_trigger(ctx,
        deployment_id: ctx.stg.id,
        target_name: target_name,
        updated_at: two_minutes_ago(),
        state: state
      )
    end

    assert MetricsQueries.count_stuck_triggers() == 3
  end

  test "count_stuck_triggers/1 when state = :INITIALIZING then returns the correct number", ctx do
    insert_trigger(ctx, deployment_id: ctx.stg.id, target_name: "staging", state: :INITIALIZING)
    assert MetricsQueries.count_stuck_triggers(:INITIALIZING) == 0

    insert_trigger(ctx,
      deployment_id: ctx.stg.id,
      target_name: "old_staging",
      updated_at: two_minutes_ago(),
      state: :INITIALIZING
    )

    assert MetricsQueries.count_stuck_triggers(:INITIALIZING) == 1
  end

  test "count_stuck_triggers/1 when state = :TRIGGERING then returns the correct number", ctx do
    insert_trigger(ctx, deployment_id: ctx.stg.id, target_name: "staging", state: :TRIGGERING)
    assert MetricsQueries.count_stuck_triggers(:TRIGGERING) == 0

    insert_trigger(ctx,
      deployment_id: ctx.stg.id,
      target_name: "old_staging",
      updated_at: two_minutes_ago(),
      state: :TRIGGERING
    )

    assert MetricsQueries.count_stuck_triggers(:TRIGGERING) == 1
  end

  test "count_stuck_triggers/1 when state = :STARTING then returns the correct number", ctx do
    insert_trigger(ctx, deployment_id: ctx.stg.id, target_name: "staging", state: :STARTING)
    assert MetricsQueries.count_stuck_triggers(:STARTING) == 0

    insert_trigger(ctx,
      deployment_id: ctx.stg.id,
      target_name: "old_staging",
      updated_at: two_minutes_ago(),
      state: :STARTING
    )

    assert MetricsQueries.count_stuck_triggers(:STARTING) == 1
  end

  defp two_minutes_ago(), do: DateTime.utc_now() |> DateTime.add(-120) |> DateTime.to_naive()

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE switches CASCADE;")
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")
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

  defp setup_staging_example(context) do
    {:ok,
     stg:
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
         secret_name: "Staging secret name"
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
         secret_id: UUID.uuid4(),
         secret_name: "Production secret name"
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

  defp insert_trigger(context, extra) do
    defaults = %{
      git_ref_type: context.switch.git_ref_type,
      git_ref_label: context.switch.label,
      triggered_by: context.triggered_by,
      triggered_at: context.triggered_at,
      switch_trigger_id: context.switch_trigger_id,
      switch_id: context.switch_id,
      request_token: UUID.uuid4(),
      switch_trigger_params: context.switch_trigger_params
    }

    trigger_entity = struct!(DeploymentTrigger, Map.merge(defaults, Map.new(extra)))
    {:ok, trigger: EctoRepo.insert!(trigger_entity)}
  end
end
