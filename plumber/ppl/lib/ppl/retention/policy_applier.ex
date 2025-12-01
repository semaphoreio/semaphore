defmodule Ppl.Retention.PolicyApplier do
  @moduledoc """
  Marks pipelines for expiration when an organization policy is applied.
  """

  import Ecto.Query

  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests

  @doc """
  Sets `expires_at` on all pipelines for `org_id` inserted before `cutoff`.
  Pipelines already marked with an earlier or equal expiration are left untouched.
  Returns the number of rows affected.
  """
  @spec mark_expiring(String.t(), NaiveDateTime.t()) :: non_neg_integer()
  def mark_expiring(org_id, cutoff) do
    query =
      from(pr in PplRequests,
        where: fragment("?->>?", pr.request_args, "organization_id") == ^org_id,
        where: pr.inserted_at < ^cutoff,
        where: is_nil(pr.expires_at) or pr.expires_at > ^cutoff
      )

    {count, _} = EctoRepo.update_all(query, set: [expires_at: cutoff])
    count
  end
end
