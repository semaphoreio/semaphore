defmodule Gofer.DeploymentTrigger.Engine.ScannerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries, as: TriggerQueries
  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger, as: Trigger

  alias Gofer.DeploymentTrigger.Engine.Scanner
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch
  alias Gofer.EctoRepo

  setup [
    :truncate_database,
    :init_context,
    :insert_deployment,
    :insert_switch,
    :insert_triggers,
    :init_state
  ]

  describe "start_link/1" do
    test "when there are no errors then it is not restarted" do
      :erlang.process_flag(:trap_exit, true)

      assert {:ok, pid} = Scanner.start_link(start_worker_fun: &start_worker_success/1)
      assert_receive {:EXIT, ^pid, :normal}, 1_000
    end

    test "when there are errors then it is restarted" do
      :erlang.process_flag(:trap_exit, true)

      assert {:ok, pid} = Scanner.start_link(start_worker_fun: &start_worker_failure/1)
      assert_receive {:EXIT, ^pid, :restart}, 1_000
    end
  end

  describe "scan/3" do
    test "when there are initializing triggers then starts them", ctx do
      assert {:ok, 19} = Scanner.scan(0, ctx[:state])

      assert ctx[:trigger_ids]
             |> Enum.filter(&match?({:INITIALIZING, _}, &1))
             |> MapSet.new(&elem(&1, 1))
             |> MapSet.subset?(Process.get(:triggers))
    end

    test "when there are triggering triggers then starts them", ctx do
      assert {:ok, 19} = Scanner.scan(0, ctx[:state])

      assert ctx[:trigger_ids]
             |> Enum.filter(&match?({:TRIGGERING, _}, &1))
             |> MapSet.new(&elem(&1, 1))
             |> MapSet.subset?(Process.get(:triggers))
    end

    test "when there are starting triggers then starts them", ctx do
      assert {:ok, 19} = Scanner.scan(0, ctx[:state])

      assert ctx[:trigger_ids]
             |> Enum.filter(&match?({:STARTING, _}, &1))
             |> MapSet.new(&elem(&1, 1))
             |> MapSet.subset?(Process.get(:triggers))
    end

    test "when syncing is already started then takes it into account", ctx do
      Process.put(:triggers, MapSet.new(ctx[:trigger_ids], &elem(&1, 1)))

      assert {:ok, 19} = Scanner.scan(0, ctx[:state])

      assert ctx[:trigger_ids]
             |> MapSet.new(&elem(&1, 1))
             |> MapSet.subset?(Process.get(:triggers))
    end

    test "when there is an error starting syncing then fails", ctx do
      assert {:error, :reason} =
               Scanner.scan(0, Map.put(ctx[:state], :start_worker_fun, &start_worker_failure/1))
    end
  end

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")
    :ok
  end

  defp init_context(_context) do
    {:ok, organization_id: UUID.uuid4(), project_id: UUID.uuid4()}
  end

  defp init_state(_context) do
    {:ok,
     state: %{
       scanner_fun: &TriggerQueries.scan_runnable/3,
       start_worker_fun: &start_worker_success/1,
       startup_time: NaiveDateTime.utc_now(),
       batch_size: 5
     }}
  end

  defp start_worker_success(trigger) do
    triggers = Process.get(:triggers, MapSet.new())
    new_triggers = MapSet.put(triggers, trigger.id)
    Process.put(:triggers, new_triggers)

    random_pid = :c.pid(0, :rand.uniform(4_096), :rand.uniform(64))

    if MapSet.member?(triggers, trigger.id),
      do: {:error, {:already_started, random_pid}},
      else: {:ok, random_pid}
  end

  defp start_worker_failure(_deployment_id) do
    {:error, :reason}
  end

  defp insert_deployment(_context) do
    deployment =
      EctoRepo.insert!(%Deployment{
        name: "Deployment",
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        unique_token: UUID.uuid4(),
        created_by: UUID.uuid4(),
        updated_by: UUID.uuid4(),
        state: :FINISHED
      })

    {:ok, deployment: deployment}
  end

  defp insert_switch(_context) do
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

  defp insert_triggers(context) do
    trigger_ids =
      Enum.concat([
        for number <- 1..5 do
          {:INITIALIZING,
           create_trigger(context.switch, context.deployment, number, :INITIALIZING).id}
        end,
        for number <- 6..12 do
          {:TRIGGERING,
           create_trigger(context.switch, context.deployment, number, :TRIGGERING).id}
        end,
        for number <- 13..19 do
          {:STARTING, create_trigger(context.switch, context.deployment, number, :STARTING).id}
        end,
        for number <- 20..30 do
          {:DONE, create_trigger(context.switch, context.deployment, number, :DONE).id}
        end
      ])

    {:ok, trigger_ids: trigger_ids}
  end

  defp create_trigger(switch, deployment, number, state) do
    EctoRepo.insert!(%Trigger{
      deployment: deployment,
      switch: switch,
      git_ref_type: switch.git_ref_type,
      git_ref_label: switch.label,
      triggered_by: UUID.uuid4(),
      triggered_at: DateTime.utc_now(),
      state: state,
      switch_trigger_id: UUID.uuid4(),
      target_name: "target #{div(number, 4) |> to_string()}",
      request_token: UUID.uuid4(),
      switch_trigger_params: %{}
    })
  end
end
