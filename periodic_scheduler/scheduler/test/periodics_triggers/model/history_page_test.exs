defmodule Scheduler.PeriodicsTriggers.Model.HistoryPage.Test do
  use ExUnit.Case, async: true

  alias Scheduler.PeriodicsTriggers.Model.HistoryPage

  setup [:truncate_database, :setup_periodic]

  describe "load/1 when current_cursor == :FIRST" do
    test "and there are no triggers", ctx do
      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, :FIRST)

      assert Enum.empty?(results)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and has more triggers than page size", ctx do
      insert_triggers_for_past(ctx, 14, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, :FIRST)

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and has less triggers than page size", ctx do
      insert_triggers_for_past(ctx, 8, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, :FIRST)

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 9, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end
  end

  describe "load/1 when current_cursor == {:BEFORE, datetime}" do
    test "there are no triggers", ctx do
      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 6, :days)})

      assert Enum.empty?(results)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the only page", ctx do
      insert_triggers_for_past(ctx, 8, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 5, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 9, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 6, :hours)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and is the nearly the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 1, :days)})

      assert_all_results_before?(ctx, results, 1, :days)
      assert_all_results_after?(ctx, results, 12, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 2, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 11, :days)
    end

    test "and overlaps the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 5, :days)})

      assert_all_results_before?(ctx, results, 5, :days)
      assert_all_results_after?(ctx, results, 16, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 6, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 15, :days)
    end

    test "and barely overlaps the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 9, :days)})

      assert_all_results_before?(ctx, results, 9, :days)
      assert_all_results_after?(ctx, results, 20, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 10, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 19, :days)
    end

    test "and nearly overlaps the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 10, :days)})

      assert_all_results_before?(ctx, results, 10, :days)
      assert_all_results_after?(ctx, results, 21, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 11, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 20, :days)
    end

    test "and is not the first page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 24, :days)})

      assert_all_results_before?(ctx, results, 24, :days)
      assert_all_results_after?(ctx, results, 35, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 25, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 34, :days)
    end

    test "and nearly overlaps the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 31, :days)})

      assert_all_results_before?(ctx, results, 31, :days)
      assert_all_results_after?(ctx, results, 42, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 32, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 41, :days)
    end

    test "and barely overlaps the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 32, :days)})

      assert_all_results_before?(ctx, results, 32, :days)
      assert_all_results_after?(ctx, results, 43, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 33, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 42, :days)
    end

    test "and overlaps the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 36, :days)})

      assert_all_results_before?(ctx, results, 36, :days)
      assert_all_results_after?(ctx, results, 47, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 37, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 46, :days)
    end

    test "and is the nearly the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 39, :days)})

      assert_all_results_before?(ctx, results, 39, :days)
      assert_all_results_after?(ctx, results, 50, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 40, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 49, :days)
    end

    test "and is the last page and has fewer than max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 44, :days)})

      assert_all_results_before?(ctx, results, 44, :days)
      assert_all_results_after?(ctx, results, 51, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 45, :days)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the last page and has exactly max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 40, :days)})

      assert_all_results_before?(ctx, results, 40, :days)
      assert_all_results_after?(ctx, results, 51, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 41, :days)
      assert_is_cursor_empty?(ctx, cursor_before)
    end
  end

  describe "load/1 when current_cursor == {:AFTER, datetime}" do
    test "there are no triggers", ctx do
      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 6, :days)})

      assert Enum.empty?(results)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the only page", ctx do
      insert_triggers_for_past(ctx, 7, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 5, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 9, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the latest page and would have had fewer than max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 9, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and is the latest page and would have had slightly fewer than max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 10, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and is the latest page and would have had max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 11, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and is nearly the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 12, :days)})

      assert_all_results_before?(ctx, results, 1, :days)
      assert_all_results_after?(ctx, results, 12, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 2, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 11, :days)
    end

    test "and overlaps the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 17, :days)})

      assert_all_results_before?(ctx, results, 6, :days)
      assert_all_results_after?(ctx, results, 17, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 7, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 16, :days)
    end

    test "and is not the first page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 35, :days)})

      assert_all_results_before?(ctx, results, 24, :days)
      assert_all_results_after?(ctx, results, 35, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 25, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 34, :days)
    end

    test "and is nearly the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 50, :days)})

      assert_all_results_before?(ctx, results, 39, :days)
      assert_all_results_after?(ctx, results, 50, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 40, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 49, :days)
    end

    test "and is the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 51, :days)})

      assert_all_results_before?(ctx, results, 40, :days)
      assert_all_results_after?(ctx, results, 51, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 41, :days)
      assert_is_cursor_empty?(ctx, cursor_before)
    end
  end

  describe "load/1 with filters" do
    setup ctx do
      insert_triggers_for_past(ctx, 15, :days)

      ctx
    end

    test "filters for particular branch", ctx do
      insert_triggers_for_past(ctx, 15..22, :days, reference: "develop")

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 2, :days)},
                 reference: %{
                   normalized: "refs/heads/develop",
                   short: "develop",
                   original: "develop"
                 }
               )

      assert Enum.all?(results, &(&1.reference == "develop"))
      assert Enum.count(results) == 7
    end

    test "filters for particular branch with new reference format", ctx do
      insert_triggers_for_past(ctx, 15..22, :days, reference: "refs/heads/develop")

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 2, :days)},
                 reference: %{
                   normalized: "refs/heads/develop",
                   short: "develop",
                   original: "develop"
                 }
               )

      assert Enum.all?(results, &(&1.reference == "refs/heads/develop"))
      assert Enum.count(results) == 7
    end

    test "filters for particular pipeline file", ctx do
      insert_triggers_for_past(ctx, 16..24, :days, pipeline_file: ".semaphore/semaphore.yml")

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 2, :days)},
                 pipeline_file: ".semaphore/semaphore.yml"
               )

      assert Enum.all?(results, &(&1.pipeline_file == ".semaphore/semaphore.yml"))
      assert Enum.count(results) == 8
    end

    test "filters for particular triggerer", ctx do
      triggerer_id = UUID.uuid4()
      insert_triggers_for_past(ctx, 17..30, :days, triggered_by: triggerer_id)

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, :FIRST, triggered_by: triggerer_id)

      assert Enum.all?(results, &(&1.run_now_requester_id == triggerer_id))
      assert Enum.count(results) == 10
    end
  end

  defp assert_is_cursor_ago?(ctx, cursor, amount, unit) do
    assert ctx.now |> ago(amount, unit) |> DateTime.truncate(:microsecond) ==
             DateTime.from_unix!(cursor, :microsecond)
  end

  defp assert_is_cursor_empty?(_ctx, cursor), do: is_nil(cursor)

  defp assert_all_results_before?(ctx, results, amount, unit) do
    compare_all_before? = fn datetimes, datetime ->
      Enum.all?(datetimes, &(DateTime.diff(&1, datetime) < 0))
    end

    assert compare_all_before?.(
             Enum.map(results, & &1.triggered_at),
             ctx.now |> ago(amount, unit)
           )
  end

  defp assert_all_results_after?(ctx, results, amount, unit) do
    compare_all_after? = fn datetimes, datetime ->
      Enum.all?(datetimes, &(DateTime.diff(&1, datetime) > 0))
    end

    assert compare_all_after?.(
             Enum.map(results, & &1.triggered_at),
             ctx.now |> ago(amount, unit)
           )
  end

  defp insert_triggers_for_past(ctx, interval, unit, params \\ [])

  defp insert_triggers_for_past(ctx, range = %Range{}, unit, params) do
    for i <- range do
      params =
        Keyword.merge(params,
          triggered_at: ago(ctx.now, i, unit),
          triggered_at: ago(ctx.now, i, unit)
        )

      insert_trigger(ctx, params)
    end
  end

  defp insert_triggers_for_past(ctx, amount, unit, params) when is_integer(amount) do
    insert_triggers_for_past(ctx, Range.new(1, amount), unit, params)
  end

  defp load_page_with_cursor(ctx, cursor, filters \\ []) do
    HistoryPage.load(%HistoryPage{
      periodic_id: ctx.periodic.id,
      current_cursor: cursor,
      filters: Map.new(filters),
      max_size: 10
    })
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
