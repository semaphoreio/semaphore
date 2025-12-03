defmodule Ppl.Retention.PolicyApplier do
  @moduledoc """
  Marks pipelines for expiration when an organization policy is applied.
  """

  import Ecto.Query

  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests

  @soft_delete_days 15

  @doc """
  Applies retention policy for `org_id` with given `cutoff` date.

  - Pipelines inserted before `cutoff` are marked with `expires_at = now + 15 days`
  - Pipelines inserted on or after `cutoff` have their `expires_at` cleared (unmarked)

  Returns `{marked_count, unmarked_count}`.
  """
  @spec mark_expiring(String.t(), NaiveDateTime.t()) :: {non_neg_integer(), non_neg_integer()}
  def mark_expiring(org_id, cutoff) do
    expires_at = NaiveDateTime.utc_now() |> NaiveDateTime.add(@soft_delete_days, :day)

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
end
