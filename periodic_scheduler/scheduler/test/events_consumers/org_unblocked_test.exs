defmodule Scheduler.EventsConsumers.OrgUnblocked.Test do
  use ExUnit.Case

  alias InternalApi.Organization.OrganizationUnblocked
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.EventsConsumers.OrgUnblocked
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Actions
  alias Util.Proto

  setup do
    Test.Helpers.truncate_db()

    Test.Helpers.purge_queue("unblocked")

    ids_1 = Test.Helpers.seed_front_db()
    ids_2 = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    System.put_env("GITHUB_APP_ID", "client_id")
    System.put_env("GITHUB_SECRET_ID", "client_secret")

    {:ok, %{ids_1: ids_1, ids_2: ids_2}}
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

    assert {:ok, _pid} = OrgUnblocked.start_link()

    Tackle.publish(encoded, exchange_params())

    :timer.sleep(2_000)

    assert_only_periodics_from_unblocked_org_unsuspended(periodics, ctx.ids_1.org_id)
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

  defp exchange_params() do
    %{
      url: System.get_env("RABBITMQ_URL"),
      exchange: "organization_exchange",
      routing_key: "unblocked"
    }
  end
end
