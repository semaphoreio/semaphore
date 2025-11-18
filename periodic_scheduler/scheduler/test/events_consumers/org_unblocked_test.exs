defmodule Scheduler.EventsConsumers.OrgUnblocked.Test do
  use ExUnit.Case

  import Ecto.Query, only: [from: 2]

  alias InternalApi.Organization.OrganizationUnblocked
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.PeriodicsRepo
  alias Scheduler.EventsConsumers.OrgUnblocked
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Actions
  alias Util.Proto

  @grpc_port 50_057
  @mocked_services [Test.MockFeatureService]

  setup_all do
    GRPC.Server.start(@mocked_services, @grpc_port)
    {:ok, consumer_pid} = start_org_unblocked_consumer()

    on_exit(fn ->
      stop_org_unblocked_consumer(consumer_pid)
      GRPC.Server.stop(@mocked_services)
    end)

    :ok
  end

  setup do
    Test.Helpers.truncate_db()

    Test.Helpers.purge_queue("unblocked")

    ids_1 = Test.Helpers.seed_front_db()
    ids_2 = Test.Helpers.seed_front_db()
    ids_3 = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    System.put_env("GITHUB_APP_ID", "client_id")
    System.put_env("GITHUB_SECRET_ID", "client_secret")

    reset_mock_feature_service()
    mock_feature_response("just_run")

    {:ok, %{ids_1: ids_1, ids_2: ids_2, ids_3: ids_3}}
  end

  test "valid message received => all periodics from the org are unsuspended", ctx do
    periodics =
      1..5
      |> Enum.map(fn ind ->
        if ind < 3 do
          create_periodic(ctx.ids_1, ind)
        else
          create_periodic(ctx.ids_2, ind)
        end
      end)

    Enum.map(periodics, fn {:ok, id} ->
      assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)
      assert periodic.suspended == true
      assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
    end)

    event = Proto.deep_new!(OrganizationUnblocked, %{org_id: ctx.ids_1.org_id})
    encoded = OrganizationUnblocked.encode(event)

    Tackle.publish(encoded, exchange_params())

    :timer.sleep(2_000)

    assert_only_periodics_from_unblocked_org_unsuspended(periodics, ctx.ids_1.org_id)
  end

  test "invalid cron expression does not block unsuspending other periodics", ctx do
    [{:ok, first_id}, {:ok, invalid_id}, {:ok, nil_cron_id}, {:ok, third_id}] =
      1..4
      |> Enum.map(&create_periodic(ctx.ids_3, &1))

    invalidate_cron_expression(invalid_id)
    remove_cron_expression(nil_cron_id)

    event = Proto.deep_new!(OrganizationUnblocked, %{org_id: ctx.ids_3.org_id})
    encoded = OrganizationUnblocked.encode(event)

    Tackle.publish(encoded, exchange_params())

    :timer.sleep(2_000)

    assert {:ok, first_periodic} = PeriodicsQueries.get_by_id(first_id)
    assert first_periodic.suspended == false
    assert nil != first_id |> String.to_atom() |> QuantumScheduler.find_job()

    assert {:ok, invalid_periodic} = PeriodicsQueries.get_by_id(invalid_id)
    assert invalid_periodic.suspended == false
    assert nil == invalid_id |> String.to_atom() |> QuantumScheduler.find_job()

    assert {:ok, nil_cron_periodic} = PeriodicsQueries.get_by_id(nil_cron_id)
    assert nil_cron_periodic.suspended == false
    assert nil == nil_cron_id |> String.to_atom() |> QuantumScheduler.find_job()

    assert {:ok, third_periodic} = PeriodicsQueries.get_by_id(third_id)
    assert third_periodic.suspended == false
    assert nil != third_id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  defp create_periodic(ids, ind) do
    {:ok, id} =
      %{
        requester_id: ids.usr_id,
        organization_id: ids.org_id,
        yml_definition: valid_yml_definition(%{name: "PS #{ind}"})
      }
      |> Actions.apply()

    {:ok, periodic} = PeriodicsQueries.get_by_id(id)

    PeriodicsQueries.suspend(periodic)
    id |> String.to_atom() |> QuantumScheduler.delete_job()

    {:ok, id}
  end

  defp valid_yml_definition(params) do
    %{
      branch: "master",
      at: "0 0 * * * *",
      project: "Project 1",
      name: "P1",
      pipeline_file: ".semaphore/cron.yml"
    }
    |> Map.merge(params)
    |> Support.Yaml.valid_definition()
  end

  defp assert_only_periodics_from_unblocked_org_unsuspended(periodics, org_id) do
    Enum.map(periodics, fn {:ok, id} ->
      assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)

      if periodic.organization_id == org_id do
        assert periodic.suspended == false
        assert nil != id |> String.to_atom() |> QuantumScheduler.find_job()
      else
        assert periodic.suspended == true
        assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
      end
    end)
  end

  defp invalidate_cron_expression(id) do
    from(p in Periodics, where: p.id == ^id)
    |> PeriodicsRepo.update_all(set: [at: "invalid cron"])
  end

  defp remove_cron_expression(id) do
    from(p in Periodics, where: p.id == ^id)
    |> PeriodicsRepo.update_all(set: [at: nil])
  end

  defp exchange_params() do
    %{
      url: System.get_env("RABBITMQ_URL"),
      exchange: "organization_exchange",
      routing_key: "unblocked"
    }
  end

  defp start_org_unblocked_consumer do
    case OrgUnblocked.start_link() do
      {:ok, pid} ->
        wait_for_org_unblocked_consumer()
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        wait_for_org_unblocked_consumer()
        {:ok, pid}

      error ->
        error
    end
  end

  defp wait_for_org_unblocked_consumer do
    # Give Tackle time to register a default consumer before publishing
    Process.sleep(200)
  end

  defp stop_org_unblocked_consumer(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      GenServer.stop(pid)
    else
      :ok
    end
  end

  defp stop_org_unblocked_consumer(_), do: :ok

  defp reset_mock_feature_service() do
    Cachex.clear(Elixir.Scheduler.FeatureHubProvider)

    Application.put_env(
      :scheduler,
      :feature_api_grpc_endpoint,
      "localhost:#{inspect(@grpc_port)}"
    )
  end

  defp mock_feature_response(value),
    do: Application.put_env(:scheduler, :mock_feature_service_response, value)
end
