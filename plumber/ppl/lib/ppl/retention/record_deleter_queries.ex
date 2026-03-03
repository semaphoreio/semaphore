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
    EctoRepo.transaction(fn ->
      limit
      |> fetch_expired_ids()
      |> delete_records()
    end)
  rescue
    e -> {:error, e}
  end

  defp fetch_expired_ids(limit) do
    now = NaiveDateTime.utc_now()

    from(pr in PplRequests,
      where: pr.expires_at < ^now,
      select: pr.id,
      limit: ^limit,
      lock: "FOR UPDATE SKIP LOCKED"
    )
    |> EctoRepo.all()
  end

  defp delete_records([]), do: 0

  defp delete_records(ids) do
    Enum.each(ids, &Block.delete_blocks_from_ppl/1)

    {count, _} =
      from(pr in PplRequests, where: pr.id in ^ids)
      |> EctoRepo.delete_all()

    count
  end
end
