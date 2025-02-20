defmodule Scheduler.Workers.Initializer.Test do
  use ExUnit.Case

  alias Scheduler.Workers.Initializer
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Periodics.Model.PeriodicsQueries

  setup do
    Test.Helpers.truncate_db()
    ids = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    System.put_env("GITHUB_APP_ID", "client_id")
    System.put_env("GITHUB_SECRET_ID", "client_secret")

    assert {:ok, per_1} = periodic_params(ids, 1) |> PeriodicsQueries.insert()
    assert {:ok, per_2} = periodic_params(ids, 2) |> PeriodicsQueries.insert()
    assert {:ok, per_3} = periodic_params(ids, 3) |> PeriodicsQueries.insert()
    assert {:ok, per_3} = PeriodicsQueries.suspend(per_3)
    assert {:ok, per_4} = periodic_params(ids, 4) |> PeriodicsQueries.insert()
    assert {:ok, per_4} = PeriodicsQueries.pause(per_4, "user_1")

    assert {:ok, per_5} =
             periodic_params(ids, 5)
             |> Map.merge(%{recurring: false, at: ""})
             |> PeriodicsQueries.insert()

    {:ok, %{ids: ids, per_1: per_1, per_2: per_2, per_3: per_3, per_4: per_4, per_5: per_5}}
  end

  defp periodic_params(ids, ind) do
    %{
      requester_id: ids.usr_id,
      organization_id: ids.org_id,
      name: "Periodic_#{ind}",
      project_name: "Project_1",
      project_id: ids.pr_id,
      branch: "master",
      at: "* * * * *",
      pipeline_file: "deploy.yml"
    }
  end

  test "quantom jobs are started for all periodics that are not supended, paused or non-recurring",
       ctx do
    assert [] = QuantumScheduler.jobs()

    assert {:stop, :normal, %{}} == Initializer.handle_info(:scann_db, %{})

    assert jobs = QuantumScheduler.jobs()
    assert length(jobs) == 2

    assert nil != ctx.per_1.id |> String.to_atom() |> QuantumScheduler.find_job()
    assert nil != ctx.per_2.id |> String.to_atom() |> QuantumScheduler.find_job()
    assert nil == ctx.per_3.id |> String.to_atom() |> QuantumScheduler.find_job()
    assert nil == ctx.per_4.id |> String.to_atom() |> QuantumScheduler.find_job()
    assert nil == ctx.per_5.id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "exits gracefuly when there are no periodics to start" do
    Test.Helpers.truncate_db()

    assert {:stop, :normal, %{}} == Initializer.handle_info(:scann_db, %{})
    assert [] = QuantumScheduler.jobs()
  end

  test "does not break if some periodic jobs are already started", ctx do
    assert [] = QuantumScheduler.jobs()

    assert {:ok, _job} = QuantumScheduler.start_periodic_job(ctx.per_1)
    assert jobs = QuantumScheduler.jobs()
    assert length(jobs) == 1

    assert {:stop, :normal, %{}} == Initializer.handle_info(:scann_db, %{})

    assert jobs = QuantumScheduler.jobs()
    assert length(jobs) == 2

    assert nil != ctx.per_1.id |> String.to_atom() |> QuantumScheduler.find_job()
    assert nil != ctx.per_2.id |> String.to_atom() |> QuantumScheduler.find_job()
    assert nil == ctx.per_3.id |> String.to_atom() |> QuantumScheduler.find_job()
    assert nil == ctx.per_4.id |> String.to_atom() |> QuantumScheduler.find_job()
    assert nil == ctx.per_5.id |> String.to_atom() |> QuantumScheduler.find_job()
  end
end
