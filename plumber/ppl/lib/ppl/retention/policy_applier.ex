defmodule Ppl.Retention.PolicyApplier do
  @moduledoc """
  Marks pipelines for expiration when an organization policy is applied.
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

  Updates are performed in batches to avoid lock contention and connection timeouts.
  The grace period is configurable via application config (default: 15 days, min: 7 days).
  Batch size is configurable via application config (default: 10_000).

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
    ids_query =
      from(pr in PplRequests,
        where: fragment("?->>?", pr.request_args, "organization_id") == ^org_id,
        where: pr.inserted_at < ^cutoff,
        where: is_nil(pr.expires_at),
        select: pr.id,
        limit: ^batch_size
      )

    ids = EctoRepo.all(ids_query)

    case ids do
      [] ->
        acc

      ids ->
        update_query = from(pr in PplRequests, where: pr.id in ^ids)
        {count, _} = EctoRepo.update_all(update_query, set: [expires_at: expires_at])
        batch_update_mark(org_id, cutoff, expires_at, batch_size, acc + count)
    end
  end

  defp batch_update_unmark(org_id, cutoff, batch_size, acc) do
    ids_query =
      from(pr in PplRequests,
        where: fragment("?->>?", pr.request_args, "organization_id") == ^org_id,
        where: pr.inserted_at >= ^cutoff,
        where: not is_nil(pr.expires_at),
        select: pr.id,
        limit: ^batch_size
      )

    ids = EctoRepo.all(ids_query)

    case ids do
      [] ->
        acc

      ids ->
        update_query = from(pr in PplRequests, where: pr.id in ^ids)
        {count, _} = EctoRepo.update_all(update_query, set: [expires_at: nil])
        batch_update_unmark(org_id, cutoff, batch_size, acc + count)
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
      Logger.warning(
        "[Retention] org_id=#{org_id} grace_period_days=#{days} is below minimum, using #{@min_grace_period_days}"
      )

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
