defmodule Scheduler.EventsConsumers.OrgBlocked.Test do
  use ExUnit.Case

  alias InternalApi.Organization.OrganizationBlocked
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.EventsConsumers.OrgBlocked
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Actions
  alias Util.Proto

  setup do
    Test.Helpers.truncate_db()

    Test.Helpers.purge_queue("blocked")

    ids_1 = Test.Helpers.seed_front_db()
    ids_2 = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    System.put_env("GITHUB_APP_ID", "client_id")
    System.put_env("GITHUB_SECRET_ID", "client_secret")

    {:ok, %{ids_1: ids_1, ids_2: ids_2}}
  end

  test "valid message received => all periodics from the org are suspended", ctx do
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
      assert periodic.suspended == false
      assert nil != id |> String.to_atom() |> QuantumScheduler.find_job()
    end)

    event = Proto.deep_new!(OrganizationBlocked, %{org_id: ctx.ids_1.org_id})
    encoded = OrganizationBlocked.encode(event)

    assert {:ok, _pid} = OrgBlocked.start_link()

    Tackle.publish(encoded, exchange_params())

    :timer.sleep(2_000)

    assert_only_periodics_from_blocked_org_suspended(periodics, ctx.ids_1.org_id)
  end

  defp create_periodic(ids, ind) do
    %{
      requester_id: ids.usr_id,
      organization_id: ids.org_id,
      yml_definition: valid_yml_definition(%{name: "PS #{ind}"})
    }
    |> Actions.apply()
  end

  defp valid_yml_definition(params) do
    %{
      reference: "master",
      at: "0 0 * * * *",
      project: "Project 1",
      name: "P1",
      pipeline_file: ".semaphore/cron.yml"
    }
    |> Map.merge(params)
    |> Support.Yaml.valid_definition()
  end

  defp assert_only_periodics_from_blocked_org_suspended(periodics, org_id) do
    Enum.map(periodics, fn {:ok, id} ->
      assert {:ok, periodic} = PeriodicsQueries.get_by_id(id)

      if periodic.organization_id == org_id do
        assert periodic.suspended == true
        assert nil == id |> String.to_atom() |> QuantumScheduler.find_job()
      else
        assert periodic.suspended == false
        assert nil != id |> String.to_atom() |> QuantumScheduler.find_job()
      end
    end)
  end

  defp exchange_params() do
    %{
      url: System.get_env("RABBITMQ_URL"),
      exchange: "organization_exchange",
      routing_key: "blocked"
    }
  end
end
