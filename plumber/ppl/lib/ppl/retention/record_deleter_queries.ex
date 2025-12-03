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

    expired_records =
      from(pr in PplRequests,
        where: pr.expires_at < ^now,
        select: %{id: pr.id, ppl_artefact_id: pr.ppl_artefact_id},
        limit: ^limit
      )
      |> EctoRepo.all()

    case expired_records do
      [] ->
        {:ok, 0}

      records ->
        Enum.each(records, fn %{ppl_artefact_id: ppl_id} ->
          Block.delete_blocks_from_ppl(ppl_id)
        end)

        ids = Enum.map(records, & &1.id)

        delete_query =
          from(pr in PplRequests,
            where: pr.id in ^ids
          )

        {count, _} = EctoRepo.delete_all(delete_query)
        {:ok, count}
    end
  rescue
    e -> {:error, e}
  end
end
