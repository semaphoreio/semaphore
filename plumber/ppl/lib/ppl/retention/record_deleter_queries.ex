defmodule Ppl.Retention.RecordDeleterQueries do
  @moduledoc """
  Database queries for the retention record deleter.
  """

  alias Ecto.Multi
  alias Ppl.EctoRepo
  alias Ppl.Retention.PipelineDeletionQueries
  alias Ppl.Retention.WorkflowDeletionQueries

  @type record :: {pipeline_id :: String.t(), workflow_id :: String.t(), request_args :: map()}

  @doc """
  Deletes up to `limit` expired records (where expires_at < now).
  First deletes associated blocks, then deletes the ppl_requests.
  Returns the count of deleted records.
  """
  @spec delete_expired_batch(limit :: non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def delete_expired_batch(limit) do
    limit
    |> deletion_multi()
    |> EctoRepo.transaction()
    |> case do
      {:ok, %{records: records, delete_pipelines: count}} ->
        PipelineDeletionQueries.publish_pipeline_deleted(records)
        WorkflowDeletionQueries.publish_workflow_deleted(records)
        {:ok, count}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  rescue
    e -> {:error, e}
  end

  @spec deletion_multi(limit :: non_neg_integer()) :: Ecto.Multi.t()
  defp deletion_multi(limit) do
    Multi.new()
    |> Multi.run(:records, fn repo, _changes ->
      {:ok, PipelineDeletionQueries.fetch_expired_records(repo, limit)}
    end)
    |> Multi.run(:delete_blocks, fn _repo, %{records: records} ->
      PipelineDeletionQueries.delete_blocks(records)
      {:ok, :ok}
    end)
    |> Multi.run(:delete_pipelines, fn repo, %{records: records} ->
      PipelineDeletionQueries.delete_pipelines(repo, records)
    end)
  end
end
