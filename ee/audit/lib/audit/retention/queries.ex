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
  @expired_count_cap 100_000

  # --- Marking / Unmarking ---

  @doc """
  Applies retention policy for `org_id` with given `cutoff` date.

  - Events with `timestamp` before `cutoff` are marked with `expires_at = now + grace_period`
  - Events with `timestamp` on or after `cutoff` have their `expires_at` cleared

  Returns `{marked_count, unmarked_count}`.
  """
  @spec mark_expiring(String.t(), DateTime.t()) :: {non_neg_integer(), non_neg_integer()}
  def mark_expiring(org_id, cutoff) do
    expires_at = compute_expires_at()
    batch_size = batch_size()

    marked_count = batch_mark(org_id, cutoff, expires_at, batch_size, 0)
    unmarked_count = batch_unmark(org_id, cutoff, batch_size, 0)

    {marked_count, unmarked_count}
  end

  defp batch_mark(org_id, cutoff, expires_at, batch_size, acc) do
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

    case count do
      0 -> acc
      n -> batch_mark(org_id, cutoff, expires_at, batch_size, acc + n)
    end
  end

  defp batch_unmark(org_id, cutoff, batch_size, acc) do
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

    case count do
      0 -> acc
      n -> batch_unmark(org_id, cutoff, batch_size, acc + n)
    end
  end

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

  # --- Deletion ---

  @doc """
  Deletes up to `limit` events where `expires_at` has passed.

  Uses FOR UPDATE SKIP LOCKED to prevent concurrent workers from
  processing the same records.

  Returns `{:ok, count}`.
  """
  @spec delete_expired_batch(pos_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def delete_expired_batch(limit) do
    Repo.transaction(fn ->
      ids = fetch_expired_ids(limit)
      delete_by_ids(ids)
    end)
  rescue
    e in [Postgrex.Error, DBConnection.ConnectionError] -> {:error, e}
  end

  defp fetch_expired_ids(limit) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(e in Event,
      where: not is_nil(e.expires_at) and e.expires_at <= ^now,
      order_by: [asc: e.expires_at],
      select: e.id,
      limit: ^limit,
      lock: "FOR UPDATE SKIP LOCKED"
    )
    |> Repo.all()
  end

  defp delete_by_ids([]), do: 0

  defp delete_by_ids(ids) do
    {count, _} =
      from(e in Event, where: e.id in ^ids)
      |> Repo.delete_all()

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
