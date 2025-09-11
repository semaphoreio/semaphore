defmodule Test.Actions.UnpauseImpl.Test do
  use ExUnit.Case

  alias Scheduler.Actions.UnpauseImpl
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Periodics.Model.PeriodicsQueries

  setup do
    Test.Helpers.truncate_db()
    params = Test.Helpers.seed_front_db()

    start_supervised!(QuantumScheduler)

    {:ok, params}
  end

  test "unpause doesn't start quantum job when scheduler is non-recurring", ctx do
    assert {:ok, periodics} = insert_periodics(ctx, recurring: false, at: "", paused: true)

    assert {:ok, "Scheduler was unpaused successfully."} =
             UnpauseImpl.unpause(%{id: periodics.id, requester: ctx.usr_id})

    assert {:ok, %{paused: false}} = PeriodicsQueries.get_by_id(periodics.id)
    refute periodics.id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  test "unpause does start quantum job when scheduler is recurring", ctx do
    assert {:ok, periodics} = insert_periodics(ctx, paused: true)

    assert {:ok, "Scheduler was unpaused successfully."} =
             UnpauseImpl.unpause(%{id: periodics.id, requester: ctx.usr_id})

    assert {:ok, %{paused: false}} = PeriodicsQueries.get_by_id(periodics.id)
    assert periodics.id |> String.to_atom() |> QuantumScheduler.find_job()
  end

  defp insert_periodics(ids, extra) do
    %{
      requester_id: ids.usr_id,
      organization_id: ids.org_id,
      name: "Periodic_1",
      project_name: "Project_1",
      recurring: if(is_nil(extra[:recurring]), do: true, else: extra[:recurring]),
      project_id: ids.pr_id,
      reference_type: "branch",
      reference_value: extra[:branch] || "master",
      at: extra[:at] || "* * * * *",
      paused: if(is_nil(extra[:paused]), do: false, else: extra[:paused]),
      pipeline_file: extra[:pipeline_file] || "deploy.yml",
      parameters: extra[:parameters] || []
    }
    |> PeriodicsQueries.insert()
  end
end
