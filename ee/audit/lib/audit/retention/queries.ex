defmodule Audit.Retention.Queries do
  @moduledoc """
  Database queries for marking audit events for expiration and deleting expired ones.
  """

  import Ecto.Query

  require Logger

  alias Audit.Event
  alias Audit.Repo

  @default_grace_period_days 15
  @min_grace_period_days 7
  @default_batch_size 1_000
  @min_batch_size 1
  # Well below the broker's delivery acknowledgement timeout (30 minutes by default).
  @default_time_limit_sec 900
  @expired_count_cap 100_000

  # --- Marking / Unmarking ---

  @doc """
  Applies retention policy for `org_id` with given `cutoff` date.

  - Events with `timestamp` on or after `cutoff` have their `expires_at` cleared
  - Events with `timestamp` before `cutoff` are marked with `expires_at = now + grace_period`

  Unmarking runs first. Each step stops once the time limit has passed, after at
  least one batch, and the next policy event for the organization continues where
  this one stopped.

  Returns `{marked_count, unmarked_count, status}`, where `status` is `:time_limit`
  if the time limit stopped the work and `:done` otherwise.
  """
  @spec mark_expiring(String.t(), DateTime.t()) ::
          {non_neg_integer(), non_neg_integer(), :done | :time_limit}
  def mark_expiring(org_id, cutoff) do
    expires_at = compute_expires_at()
    batch_size = batch_size()
    deadline = System.monotonic_time(:millisecond) + time_limit_sec() * 1_000

    {unmarked_count, unmark_status} = batch_unmark(org_id, cutoff, batch_size, deadline, 0)

    {marked_count, mark_status} = batch_mark(org_id, cutoff, expires_at, batch_size, deadline, 0)

    status = if :time_limit in [unmark_status, mark_status], do: :time_limit, else: :done

    {marked_count, unmarked_count, status}
  end

  defp batch_mark(org_id, cutoff, expires_at, batch_size, deadline, acc) do
    # `order_by: timestamp` lets the planner walk the
    # (org_id, timestamp) WHERE expires_at IS NULL partial index instead of
    # scanning the org's full retention window on every policy event.
    ids_subquery =
      from(e in Event,
        where: e.org_id == ^org_id,
        where: e.timestamp < ^cutoff,
        where: is_nil(e.expires_at),
        order_by: [asc: e.timestamp],
        select: e.id,
        limit: ^batch_size
      )

    update_query = from(e in Event, where: e.id in subquery(ids_subquery))
    {count, _} = Repo.update_all(update_query, set: [expires_at: expires_at])

    Watchman.submit({"retention.marked", []}, count, :count)

    cond do
      count == 0 -> {acc, :done}
      past?(deadline) -> {acc + count, :time_limit}
      true -> batch_mark(org_id, cutoff, expires_at, batch_size, deadline, acc + count)
    end
  end

  defp batch_unmark(org_id, cutoff, batch_size, deadline, acc) do
    # Mirrors batch_mark: ordering + the
    # (org_id, timestamp) WHERE expires_at IS NOT NULL partial index keep this
    # an index scan even when no rows match.
    base_query =
      from(e in Event,
        where: e.org_id == ^org_id,
        where: e.timestamp >= ^cutoff,
        where: not is_nil(e.expires_at),
        order_by: [asc: e.timestamp],
        select: e.id,
        limit: ^batch_size
      )

    update_query = from(e in Event, where: e.id in subquery(base_query))
    {count, _} = Repo.update_all(update_query, set: [expires_at: nil])

    Watchman.submit({"retention.unmarked", []}, count, :count)

    cond do
      count == 0 -> {acc, :done}
      past?(deadline) -> {acc + count, :time_limit}
      true -> batch_unmark(org_id, cutoff, batch_size, deadline, acc + count)
    end
  end

  defp past?(deadline), do: System.monotonic_time(:millisecond) >= deadline

  defp compute_expires_at do
    grace_period_seconds = grace_period_days() * 24 * 60 * 60

    DateTime.utc_now()
    |> DateTime.add(grace_period_seconds, :second)
    |> DateTime.truncate(:second)
  end

  defp grace_period_days do
    config = Application.get_env(:audit, __MODULE__, [])
    days = Keyword.get(config, :grace_period_days, @default_grace_period_days)

    if is_integer(days) and days >= @min_grace_period_days do
      days
    else
      @default_grace_period_days
    end
  end

  defp batch_size do
    config = Application.get_env(:audit, __MODULE__, [])
    value = Keyword.get(config, :batch_size, @default_batch_size)

    if is_integer(value) and value >= @min_batch_size do
      value
    else
      Logger.warning(
        "[Retention] invalid batch_size=#{inspect(value)} for #{inspect(__MODULE__)}, using #{@default_batch_size}"
      )

      @default_batch_size
    end
  end

  defp time_limit_sec do
    config = Application.get_env(:audit, __MODULE__, [])
    value = Keyword.get(config, :time_limit_sec, @default_time_limit_sec)

    if is_integer(value) and value >= 0 do
      value
    else
      Logger.warning(
        "[Retention] invalid time_limit_sec=#{inspect(value)} for #{inspect(__MODULE__)}, using #{@default_time_limit_sec}"
      )

      @default_time_limit_sec
    end
  end

  # --- Deletion ---

  @doc """
  Takes up to `limit` events where `expires_at` has passed. Deletes those of
  organizations for which `enabled?` returns true, and unmarks the others so they
  leave the deletion queue instead of blocking it.

  `enabled?` is called once per organization while the batch is locked, so it
  must be cheap (feature lookups are cached).

  Uses FOR UPDATE SKIP LOCKED to prevent concurrent workers from
  processing the same records.

  Returns `{:ok, %{deleted: deleted_count, unmarked: unmarked_count}}`.
  """
  @spec delete_expired_batch(pos_integer(), (String.t() -> boolean())) ::
          {:ok, %{deleted: non_neg_integer(), unmarked: non_neg_integer()}} | {:error, term()}
  def delete_expired_batch(limit, enabled?) do
    Repo.transaction(fn ->
      expired = fetch_expired(limit)

      enabled_org_ids =
        expired
        |> Enum.map(fn {_id, org_id} -> org_id end)
        |> Enum.uniq()
        |> Enum.filter(enabled?)

      {to_delete, to_unmark} =
        Enum.split_with(expired, fn {_id, org_id} -> org_id in enabled_org_ids end)

      %{deleted: delete_by_ids(ids(to_delete)), unmarked: unmark_by_ids(ids(to_unmark))}
    end)
  rescue
    e in [Postgrex.Error, DBConnection.ConnectionError] -> {:error, e}
  end

  defp fetch_expired(limit) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(e in Event,
      where: not is_nil(e.expires_at) and e.expires_at <= ^now,
      order_by: [asc: e.expires_at],
      select: {e.id, e.org_id},
      limit: ^limit,
      lock: "FOR UPDATE SKIP LOCKED"
    )
    |> Repo.all()
  end

  defp ids(events), do: Enum.map(events, fn {id, _org_id} -> id end)

  defp delete_by_ids([]), do: 0

  defp delete_by_ids(ids) do
    {count, _} =
      from(e in Event, where: e.id in ^ids)
      |> Repo.delete_all()

    count
  end

  defp unmark_by_ids([]), do: 0

  defp unmark_by_ids(ids) do
    {count, _} =
      from(e in Event, where: e.id in ^ids)
      |> Repo.update_all(set: [expires_at: nil])

    count
  end

  @doc """
  Returns a capped backlog count of currently expired rows.

  This is used for periodic telemetry only and is intentionally capped to keep
  the query bounded on very large tables.
  """
  @spec expired_count() :: {:ok, non_neg_integer(), boolean()} | {:error, term()}
  def expired_count do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    limited_expired_ids =
      from(e in Event,
        where: not is_nil(e.expires_at) and e.expires_at <= ^now,
        select: e.id,
        limit: ^@expired_count_cap
      )

    count =
      from(e in subquery(limited_expired_ids),
        select: count(e.id)
      )
      |> Repo.one()

    {:ok, count, count >= @expired_count_cap}
  rescue
    e in [Postgrex.Error, DBConnection.ConnectionError] ->
      {:error, e}
  end

  @spec expired_count_cap() :: pos_integer()
  def expired_count_cap do
    @expired_count_cap
  end
end
