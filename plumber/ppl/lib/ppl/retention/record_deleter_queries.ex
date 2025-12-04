defmodule Ppl.Retention.RecordDeleterQueries do
  @moduledoc """
  Database queries for the retention record deleter.
  """

  import Ecto.Query

  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests

  @doc """
  Deletes up to `limit` expired records (where expires_at < now).
  Returns the count of deleted records.
  """
  @spec delete_expired_batch(non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def delete_expired_batch(limit) do
    now = NaiveDateTime.utc_now()

    subquery =
      from(pr in PplRequests,
        where: pr.expires_at < ^now,
        select: pr.id,
        limit: ^limit
      )

    delete_query =
      from(pr in PplRequests,
        where: pr.id in subquery(subquery)
      )

    {count, _} = EctoRepo.delete_all(delete_query)
    {:ok, count}
  rescue
    e -> {:error, e}
  end
end
