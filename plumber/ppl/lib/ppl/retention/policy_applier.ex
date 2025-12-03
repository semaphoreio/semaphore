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

  @doc """
  Applies retention policy for `org_id` with given `cutoff` date.

  - Pipelines inserted before `cutoff` are marked with `expires_at = now + grace_period_days`
  - Pipelines inserted on or after `cutoff` have their `expires_at` cleared (unmarked)

  The grace period is configurable via RETENTION_GRACE_PERIOD_DAYS env var (default: 15, min: 7).

  Returns `{marked_count, unmarked_count}`.
  """
  @spec mark_expiring(String.t(), NaiveDateTime.t()) :: {non_neg_integer(), non_neg_integer()}
  def mark_expiring(org_id, cutoff) do
    grace_period_days = grace_period_days()
    grace_period_seconds = grace_period_days * 24 * 60 * 60
    expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(grace_period_seconds, :second)

    mark_query =
      from(pr in PplRequests,
        where: fragment("?->>?", pr.request_args, "organization_id") == ^org_id,
        where: pr.inserted_at < ^cutoff
      )

    unmark_query =
      from(pr in PplRequests,
        where: fragment("?->>?", pr.request_args, "organization_id") == ^org_id,
        where: pr.inserted_at >= ^cutoff,
        where: not is_nil(pr.expires_at)
      )

    {marked_count, _} = EctoRepo.update_all(mark_query, set: [expires_at: expires_at])
    {unmarked_count, _} = EctoRepo.update_all(unmark_query, set: [expires_at: nil])

    {marked_count, unmarked_count}
  end

  defp grace_period_days do
    config = Application.get_env(:ppl, __MODULE__, [])
    days = Keyword.get(config, :grace_period_days, @default_grace_period_days)

    if days < @min_grace_period_days do
      Logger.warning(
        "[Retention] grace_period_days=#{days} is below minimum, using #{@min_grace_period_days}"
      )

      @min_grace_period_days
    else
      days
    end
  end
end
