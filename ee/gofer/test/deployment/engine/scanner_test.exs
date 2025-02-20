defmodule Gofer.Deployment.Engine.ScannerTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Gofer.Deployment.Engine.Scanner
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Deployment.Model.DeploymentQueries

  alias Gofer.EctoRepo

  setup [
    :truncate_database,
    :init_context,
    :insert_deployments,
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
    test "when there are syncing deployments then starts them", ctx do
      assert {:ok, 18} = Scanner.scan(0, ctx[:state])
      assert MapSet.new(ctx[:deployment_ids]) |> MapSet.equal?(Process.get(:deployments))
    end

    test "when syncing is already started then takes it into account", ctx do
      Process.put(:deployments, MapSet.new(ctx[:deployment_ids]))

      assert {:ok, 18} = Scanner.scan(0, ctx[:state])
      assert MapSet.new(ctx[:deployment_ids]) |> MapSet.equal?(Process.get(:deployments))
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
    {:ok, organization_id: UUID.uuid4(), project_id: UUID.uuid4(), user_id: UUID.uuid4()}
  end

  defp init_state(_context) do
    {:ok,
     state: %{
       scanner_fun: &DeploymentQueries.scan_syncing/3,
       start_worker_fun: &start_worker_success/1,
       startup_time: NaiveDateTime.utc_now(),
       batch_size: 5
     }}
  end

  defp start_worker_success(deployment_id) do
    deployments = Process.get(:deployments, MapSet.new())
    new_deployments = MapSet.put(deployments, deployment_id)
    Process.put(:deployments, new_deployments)

    random_pid = :c.pid(0, :rand.uniform(4_096), :rand.uniform(64))

    if MapSet.member?(deployments, deployment_id) do
      {:error, {:already_started, random_pid}}
    else
      {:ok, random_pid}
    end
  end

  defp start_worker_failure(_deployment_id) do
    {:error, :reason}
  end

  defp insert_deployments(context) do
    deployment_ids =
      for number <- 1..18 do
        %Deployment{
          name: "Deployment #{number}",
          organization_id: context[:organization_id],
          project_id: context[:project_id],
          created_by: context[:user_id],
          updated_by: context[:user_id],
          unique_token: UUID.uuid4(),
          state: :SYNCING
        }
        |> EctoRepo.insert!()
        |> Map.get(:id)
      end

    for number <- 1..7 do
      %Deployment{
        name: "Deployment #{18 + number}",
        organization_id: context[:organization_id],
        project_id: context[:project_id],
        created_by: context[:user_id],
        updated_by: context[:user_id],
        unique_token: UUID.uuid4(),
        state: :FINISHED
      }
      |> EctoRepo.insert!()
    end

    {:ok, deployment_ids: deployment_ids}
  end
end
