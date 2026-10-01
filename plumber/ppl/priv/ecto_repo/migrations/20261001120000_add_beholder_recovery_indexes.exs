defmodule Ppl.EctoRepo.Migrations.AddBeholderRecoveryIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Beholders poll these tables for rows stuck in scheduling: in_scheduling,
  # updated_at older than a threshold and state not in the excluded states
  # (["done"] for all three). Rows aborted by a Beholder keep in_scheduling
  # set in state done, so the predicate excludes them too. That keeps these
  # indexes tiny and turns the polls into index lookups instead of scans.
  @partial_indexes [
    {"after_ppl_tasks", "after_ppl_tasks_in_scheduling_not_done_updated_at_index"},
    {"time_limits", "time_limits_in_scheduling_not_done_updated_at_index"},
    {"pipeline_sub_inits", "pipeline_sub_inits_in_scheduling_not_done_updated_at_index"}
  ]

  # Serves the TimeLimits StateWatch count (WHERE state IN (...) GROUP BY
  # state) as an index-only scan. Not partial: the states are a bound
  # parameter, so a partial predicate could not be proven for generic plans.
  @state_index {"time_limits", "time_limits_state_id_index"}

  # Every pod runs migrations on boot and the migration lock is disabled for
  # concurrent index builds, so pods can run this at the same time. An index
  # that another session is still building is also not valid yet; the advisory
  # lock keeps one pod from dropping the index another pod is building.
  # It is polled with pg_try_advisory_lock: a session blocked in
  # pg_advisory_lock would itself be a transaction the other pod's
  # CREATE INDEX CONCURRENTLY waits for, which deadlocks.
  @lock_key "ppl_add_beholder_recovery_indexes"

  # Index builds on large tables outlast the default query timeout.
  @no_timeout [timeout: :infinity]

  def up do
    repo().checkout(fn ->
      acquire_lock()

      try do
        Enum.each(@partial_indexes, fn {table, name} ->
          ensure_index(
            name,
            ~s|ON "#{table}" ("updated_at") WHERE in_scheduling AND state <> 'done'|
          )
        end)

        {table, name} = @state_index
        ensure_index(name, ~s|ON "#{table}" ("state", "id")|)
      after
        repo().query!("SELECT pg_advisory_unlock(hashtext($1))", [@lock_key])
      end
    end)
  end

  def down do
    Enum.each(@partial_indexes ++ [@state_index], fn {_table, name} ->
      repo().query!(~s|DROP INDEX CONCURRENTLY IF EXISTS "#{name}"|, [], @no_timeout)
    end)
  end

  defp acquire_lock do
    case repo().query!("SELECT pg_try_advisory_lock(hashtext($1))", [@lock_key]) do
      %{rows: [[true]]} ->
        :ok

      _ ->
        Process.sleep(1_000)
        acquire_lock()
    end
  end

  # A failed CREATE INDEX CONCURRENTLY leaves an INVALID index behind, and
  # IF NOT EXISTS would then skip the build. Drop such a leftover first.
  defp ensure_index(name, definition) do
    if invalid_index?(name) do
      repo().query!(~s|DROP INDEX CONCURRENTLY IF EXISTS "#{name}"|, [], @no_timeout)
    end

    repo().query!(
      ~s|CREATE INDEX CONCURRENTLY IF NOT EXISTS "#{name}" #{definition}|,
      [],
      @no_timeout
    )
  end

  defp invalid_index?(name) do
    %{rows: rows} =
      repo().query!(
        """
        SELECT 1
        FROM pg_index i
        JOIN pg_class c ON c.oid = i.indexrelid
        WHERE c.relname = $1
          AND c.relnamespace = current_schema()::regnamespace
          AND NOT i.indisvalid
        """,
        [name]
      )

    rows != []
  end
end
