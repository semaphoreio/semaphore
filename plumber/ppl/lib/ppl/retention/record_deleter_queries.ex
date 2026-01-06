defmodule Ppl.Retention.RecordDeleterQueries do
  @moduledoc """
  Database queries for the retention record deleter.
  """

  import Ecto.Query

  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests

  @doc """
  Deletes up to `limit` expired records (where expires_at < now).
  First deletes associated blocks, then deletes the ppl_requests.
  Returns the count of deleted records.
  """
  @spec delete_expired_batch(non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def delete_expired_batch(limit) do
    now = NaiveDateTime.utc_now()

    EctoRepo.transaction(fn ->
      expired_ids =
        from(pr in PplRequests,
          where: pr.expires_at < ^now,
          select: pr.id,
          limit: ^limit,
          lock: "FOR UPDATE SKIP LOCKED"
        )
        |> EctoRepo.all()

      case expired_ids do
        [] ->
          0

        ids ->
          Enum.each(ids, fn id ->
            Block.delete_blocks_from_ppl(id)
          end)

          delete_query =
            from(pr in PplRequests,
              where: pr.id in ^ids
            )

          {count, _} = EctoRepo.delete_all(delete_query)
          count
      end
    end)
  rescue
    e -> {:error, e}
  end
end
