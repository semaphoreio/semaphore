defmodule Ppl.BeholderIndexesTest do
  @moduledoc """
  Beholder polls must be served by the partial indexes from
  20261001120000_add_beholder_recovery_indexes, not by full table scans.
  """
  use ExUnit.Case

  alias Ppl.EctoRepo, as: Repo

  @partial_indexes [
    {"after_ppl_tasks", Ppl.AfterPplTasks.Model.AfterPplTasks,
     "after_ppl_tasks_in_scheduling_not_done_updated_at_index"},
    {"time_limits", Ppl.TimeLimits.Model.TimeLimits,
     "time_limits_in_scheduling_not_done_updated_at_index"},
    {"pipeline_sub_inits", Ppl.PplSubInits.Model.PplSubInits,
     "pipeline_sub_inits_in_scheduling_not_done_updated_at_index"}
  ]

  @state_index "time_limits_state_id_index"

  @telemetry_event [:ppl, :ecto_repo, :query]

  test "indexes exist, are valid and have the expected definitions" do
    for {table, _schema, name} <- @partial_indexes do
      assert index_def(name) =~ ~r/ON public\.#{table} USING btree \(updated_at\)/
      assert index_def(name) =~ "WHERE (in_scheduling AND ((state)::text <> 'done'::text))"
      assert valid?(name)
    end

    assert index_def(@state_index) =~ "ON public.time_limits USING btree (state, id)"
    assert valid?(@state_index)
  end

  for {table, schema, name} <- @partial_indexes do
    @table table
    @schema schema
    @name name

    test "#{table} beholder polls use #{name}" do
      plans =
        in_rolled_back_tx(fn ->
          seed_aborted_rows(@table)

          queries =
            capture_queries(fn ->
              cfg = beholder_cfg(@schema)
              Looper.Beholder.Query.get_repeatedly_stuck(cfg)
              Looper.Beholder.Query.recover_stuck(cfg)
            end)

          queries
          |> Enum.filter(&String.contains?(&1.sql, ~s("#{@table}")))
          |> Enum.map(&explain/1)
        end)

      assert length(plans) == 2
      Enum.each(plans, fn plan -> assert plan =~ @name, plan end)
    end
  end

  test "time_limits StateWatch count uses #{@state_index}" do
    plan =
      in_rolled_back_tx(fn ->
        seed_aborted_rows("time_limits")

        params = %{
          schema: Ppl.TimeLimits.Model.TimeLimits,
          included_states: ~w(tracking),
          repo: Repo
        }

        [query] = capture_queries(fn -> Looper.StateWatch.Query.count_events_by_state(params) end)

        explain(query)
      end)

    assert plan =~ "Index Only Scan using #{@state_index}", plan
  end

  # excluded_states mirrors Ppl.{AfterPplTasks,TimeLimits,PplSubInits}.Beholder;
  # the thresholds only shape the query, their values do not matter here.
  # The partial index predicate (state <> 'done') relies on excluded_states
  # containing "done"; widening it there needs a matching index change.
  defp beholder_cfg(schema) do
    %{
      query: schema,
      repo: Repo,
      excluded_states: ["done"],
      threshold_sec: 20,
      threshold_count: 5
    }
  end

  # Rows a beholder aborted: state done with in_scheduling left set. Enough of
  # them that a plan reading the in_scheduling region would be visibly wrong.
  defp seed_aborted_rows(table) do
    # Skips the pipeline_requests foreign key; needs a superuser, as the test
    # database user is in docker compose and CI.
    Repo.query!("SET LOCAL session_replication_role = replica")

    {extra_col, extra_val} = extra_column(table)

    Repo.query!("""
    INSERT INTO #{table} (ppl_id, state, in_scheduling, recovery_count, inserted_at, updated_at#{
      extra_col
    })
    SELECT md5(g::text)::uuid, CASE WHEN g % 50 = 0 THEN 'running' ELSE 'done' END,
           g % 2 = 0, 0, now() - interval '1 day', now() - interval '1 day'#{extra_val}
    FROM generate_series(1, 5000) g
    """)

    Repo.query!("ANALYZE #{table}")
  end

  defp extra_column("pipeline_sub_inits"), do: {", init_type", ", 'regular'"}
  defp extra_column(_table), do: {"", ""}

  defp in_rolled_back_tx(fun) do
    {:error, {:result, result}} = Repo.transaction(fn -> Repo.rollback({:result, fun.()}) end)
    result
  end

  defp capture_queries(fun) do
    test_pid = self()
    handler = "beholder-indexes-test-#{System.unique_integer()}"

    :telemetry.attach(
      handler,
      @telemetry_event,
      fn _event, _measurements, meta, _ ->
        if self() == test_pid, do: send(test_pid, {:query, meta.query, meta.params})
      end,
      nil
    )

    try do
      fun.()
    after
      :telemetry.detach(handler)
    end

    collect_queries([])
  end

  defp collect_queries(acc) do
    receive do
      {:query, sql, params} -> collect_queries([%{sql: sql, params: params} | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  # Unnamed statement with bound params, so Postgres builds a custom plan the
  # same way it does for the beholder's own executions.
  defp explain(%{sql: sql, params: params}) do
    Repo.query!("EXPLAIN " <> sql, params).rows
    |> Enum.map_join("\n", fn [line] -> line end)
  end

  defp index_def(name) do
    %{rows: [[indexdef]]} =
      Repo.query!("SELECT indexdef FROM pg_indexes WHERE indexname = $1", [name])

    indexdef
  end

  defp valid?(name) do
    %{rows: [[valid]]} =
      Repo.query!(
        """
        SELECT i.indisvalid FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        WHERE c.relname = $1
        """,
        [name]
      )

    valid
  end
end
