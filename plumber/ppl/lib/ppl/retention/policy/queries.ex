defmodule Ppl.Retention.Policy.Queries do
  @moduledoc """
  Database queries for marking pipelines for expiration based on organization policy.
  """

  import Ecto.Query

  require Logger

  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests

  @default_grace_period_days 15
  @min_grace_period_days 7
  @default_batch_size 10_000

  @doc """
  Applies retention policy for `org_id` with given `cutoff` date.

  - Pipelines inserted before `cutoff` are marked with `expires_at = now + grace_period_days`
  - Pipelines inserted on or after `cutoff` have their `expires_at` cleared (unmarked)

  Returns `{marked_count, unmarked_count}`.
  """
  @spec mark_expiring(String.t(), NaiveDateTime.t()) :: {non_neg_integer(), non_neg_integer()}
  def mark_expiring(org_id, cutoff) do
    expires_at = compute_expires_at(org_id)
    batch_size = batch_size()

    marked_count = batch_update_mark(org_id, cutoff, expires_at, batch_size, 0)
    unmarked_count = batch_update_unmark(org_id, cutoff, batch_size, 0)

    {marked_count, unmarked_count}
  end

  defp batch_update_mark(org_id, cutoff, expires_at, batch_size, acc) do
    ids_subquery =
      from(pr in PplRequests,
        where: fragment("?->>?", pr.request_args, "organization_id") == ^org_id,
        where: pr.inserted_at < ^cutoff,
        where: is_nil(pr.expires_at),
        select: pr.id,
        limit: ^batch_size
      )

    update_query = from(pr in PplRequests, where: pr.id in subquery(ids_subquery))
    {count, _} = EctoRepo.update_all(update_query, set: [expires_at: expires_at])

    Watchman.submit({"retention.marked", [org_id]}, count, :count)

    case count do
      0 -> acc
      n -> batch_update_mark(org_id, cutoff, expires_at, batch_size, acc + n)
    end
  end

  defp batch_update_unmark(org_id, cutoff, batch_size, acc) do
    ids_subquery =
      from(pr in PplRequests,
        where: fragment("?->>?", pr.request_args, "organization_id") == ^org_id,
        where: pr.inserted_at >= ^cutoff,
        where: not is_nil(pr.expires_at),
        select: pr.id,
        limit: ^batch_size
      )

    update_query = from(pr in PplRequests, where: pr.id in subquery(ids_subquery))
    {count, _} = EctoRepo.update_all(update_query, set: [expires_at: nil])

    Watchman.submit({"retention.unmarked", [org_id]}, count, :count)

    case count do
      0 -> acc
      n -> batch_update_unmark(org_id, cutoff, batch_size, acc + n)
    end
  end

  defp compute_expires_at(org_id) do
    grace_period_seconds = grace_period_days(org_id) * 24 * 60 * 60
    NaiveDateTime.utc_now() |> NaiveDateTime.add(grace_period_seconds, :second)
  end

  defp grace_period_days(org_id) do
    config = Application.get_env(:ppl, __MODULE__, [])
    days = Keyword.get(config, :grace_period_days, @default_grace_period_days)

    if days < @min_grace_period_days do
      Logger.warning("[Retention] org_id=#{org_id} grace_period_days=#{days} below minimum, using #{@min_grace_period_days}")
      @min_grace_period_days
    else
      days
    end
  end

  defp batch_size do
    config = Application.get_env(:ppl, __MODULE__, [])
    Keyword.get(config, :batch_size, @default_batch_size)
  end
end
