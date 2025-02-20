defmodule Test.Actions.HistoryImpl.Test do
  use ExUnit.Case

  alias Scheduler.Actions.HistoryImpl

  setup [
    :truncate_database,
    :setup_periodic
  ]

  @grpc_invalid_argument GRPC.Status.invalid_argument()
  @grpc_not_found GRPC.Status.not_found()

  test "has no valid data  => :INVALID_ARGUMENT", _ctx do
    assert {:error, {@grpc_invalid_argument, "Missing argument: periodic_id"}} =
             HistoryImpl.history(%{periodic_id: ""})
  end

  test "periodic does not exist => :NOT_FOUND", _ctx do
    assert {:error, {@grpc_not_found, message}} =
             HistoryImpl.history(%{periodic_id: UUID.uuid4()})

    assert String.starts_with?(message, "Periodic")
    assert String.ends_with?(message, "not found.")
  end

  test "periodic exists and has no triggers => empty list", ctx do
    assert {:ok, %{triggers: [], cursor_before: 0, cursor_after: 0}} =
             HistoryImpl.history(%{
               periodic_id: ctx.periodic.id,
               filters: %{},
               cursor_type: :FIRST,
               cursor_value: 0
             })
  end

  test "periodic exists and has triggers => list of n latest", ctx do
    insert_triggers_for_past(ctx, 2, :days)

    assert {:ok, response = %{triggers: triggers}} =
             HistoryImpl.history(%{
               periodic_id: ctx.periodic.id,
               filters: %{},
               cursor_type: :FIRST,
               cursor_value: 0
             })

    assert [first_deployment, second_deployment] = triggers
    assert Enum.all?(triggers, &UUID.info!(&1.project_id))
    assert Enum.all?(triggers, &UUID.info!(&1.periodic_id))
    assert Enum.all?(triggers, &UUID.info!(&1.scheduled_workflow_id))
    assert Enum.all?(triggers, &UUID.info!(&1.run_now_requester_id))
    assert Enum.all?(triggers, &match?(%DateTime{}, &1.triggered_at))

    assert DateTime.compare(first_deployment.triggered_at, second_deployment.triggered_at) == :gt
    assert response.cursor_before == 0
    assert response.cursor_after == 0
  end

  test "periodic exists and has many triggers => list page with cursors", ctx do
    insert_triggers_for_past(ctx, 60, :minutes)

    assert {:ok, response = %{triggers: triggers}} =
             HistoryImpl.history(%{
               periodic_id: ctx.periodic.id,
               filters: %{branch_name: "", pipeline_file: "", triggered_by: ""},
               cursor_type: :BEFORE,
               cursor_value: cursor_ago(ctx, 20, :minutes)
             })

    assert Enum.count(triggers) == 10
    assert Enum.all?(triggers, &UUID.info!(&1.project_id))
    assert Enum.all?(triggers, &UUID.info!(&1.periodic_id))
    assert Enum.all?(triggers, &UUID.info!(&1.scheduled_workflow_id))
    assert Enum.all?(triggers, &UUID.info!(&1.run_now_requester_id))
    assert Enum.all?(triggers, &match?(%DateTime{}, &1.triggered_at))

    assert_in_delta response.cursor_before, cursor_ago(ctx, 30, :minutes), 1_000_000
    assert_in_delta response.cursor_after, cursor_ago(ctx, 21, :minutes), 1_000_000
  end

  test "periodic has many triggers and filters are passed => list page", ctx do
    insert_triggers_for_past(ctx, 60, :minutes)
    insert_triggers_for_past(ctx, 5, :minutes, branch: "develop")
    insert_triggers_for_past(ctx, 5, :minutes, pipeline_file: ".semaphore/semaphore.yml")
    insert_triggers_for_past(ctx, 5, :minutes, triggered_by: "scheduler")

    assert {:ok, %{triggers: triggers}} =
             HistoryImpl.history(%{
               periodic_id: ctx.periodic.id,
               filters: %{branch_name: "develop"},
               cursor_type: :FIRST,
               cursor_value: 0
             })

    assert Enum.count(triggers) == 5

    assert {:ok, %{triggers: triggers}} =
             HistoryImpl.history(%{
               periodic_id: ctx.periodic.id,
               filters: %{pipeline_file: ".semaphore/semaphore.yml"},
               cursor_type: :FIRST,
               cursor_value: 0
             })

    assert Enum.count(triggers) == 5

    assert {:ok, %{triggers: triggers}} =
             HistoryImpl.history(%{
               periodic_id: ctx.periodic.id,
               filters: %{triggered_by: "scheduler"},
               cursor_type: :FIRST,
               cursor_value: 0
             })

    assert Enum.count(triggers) == 5
  end

  defp insert_triggers_for_past(ctx, interval, unit, params \\ [])

  defp insert_triggers_for_past(ctx, range = %Range{}, unit, params) do
    for i <- range do
      params =
        Keyword.merge(params,
          scheduled_at: ago(ctx.now, i, unit),
          triggered_at: ago(ctx.now, i, unit)
        )

      insert_trigger(ctx, params)
    end
  end

  defp insert_triggers_for_past(ctx, amount, unit, params) when is_integer(amount) do
    insert_triggers_for_past(ctx, Range.new(1, amount), unit, params)
  end

  defp cursor_ago(ctx, amount, unit),
    do: ctx.now |> ago(amount, unit) |> DateTime.to_unix(:microsecond)

  defp ago(now, amount, :seconds), do: DateTime.add(now, -amount)
  defp ago(now, amount, :minutes), do: ago(now, amount * 60, :seconds)
  defp ago(now, amount, :hours), do: ago(now, amount * 60, :minutes)
  defp ago(now, amount, :days), do: ago(now, amount * 24, :hours)

  defdelegate truncate_database(ctx), to: Test.Support.Factory
  defdelegate setup_periodic(ctx, extra \\ []), to: Test.Support.Factory
  defdelegate insert_trigger(ctx, extra \\ []), to: Test.Support.Factory
end
