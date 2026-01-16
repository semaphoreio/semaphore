defmodule Ppl.Retention.Deleter.Queries do
  @moduledoc """
  Database queries for deleting expired pipeline records and emitting deletion events.
  """

  import Ecto.Query

  require Logger

  alias Ppl.EctoRepo
  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Retention.Events

  @type record :: {pipeline_id :: String.t(), workflow_id :: String.t(), request_args :: map()}

  @doc """
  Deletes up to `limit` expired records and emits deletion events.

  Returns `{:ok, count}` where count is the number of deleted records.
  """
  @spec delete_expired_batch(pos_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def delete_expired_batch(limit) do
    EctoRepo.transaction(fn ->
      records = fetch_expired_records(limit)
      delete_records(records)
      publish_events(records)
      length(records)
    end)
  rescue
    e -> {:error, e}
  end

  defp fetch_expired_records(limit) do
    now = NaiveDateTime.utc_now()

    from(pr in PplRequests,
      where: pr.expires_at < ^now,
      select: {pr.id, pr.wf_id, pr.request_args},
      limit: ^limit,
      lock: "FOR UPDATE SKIP LOCKED"
    )
    |> EctoRepo.all()
  end

  defp delete_records([]), do: :ok

  defp delete_records(records) do
    ids = Enum.map(records, &elem(&1, 0))
    Enum.each(ids, &Block.delete_blocks_from_ppl/1)
    from(pr in PplRequests, where: pr.id in ^ids) |> EctoRepo.delete_all()
    :ok
  end

  defp publish_events(records) do
    publish_pipeline_events(records)
    publish_workflow_events(records)
  end

  defp publish_pipeline_events(records) do
    Enum.each(records, fn {pipeline_id, workflow_id, request_args} ->
      {org_id, project_id, artifact_store_id} = extract_ids(request_args)

      case Events.publish_pipeline_deleted(pipeline_id, workflow_id, org_id, project_id, artifact_store_id) do
        :ok -> :ok
        {:error, reason} -> Logger.error("[Retention] Failed to publish pipeline deleted: #{inspect(reason)}")
      end
    end)
  end

  defp publish_workflow_events(records) do
    records
    |> unique_workflows()
    |> Enum.each(fn {workflow_id, request_args} ->
      maybe_publish_workflow_deleted(workflow_id, request_args)
    end)
  end

  defp maybe_publish_workflow_deleted(workflow_id, request_args) do
    case PplRequestsQueries.count_pipelines_in_workflow(workflow_id) do
      {:ok, 0} ->
        {org_id, project_id, artifact_store_id} = extract_ids(request_args)

        case Events.publish_workflow_deleted(workflow_id, org_id, project_id, artifact_store_id) do
          :ok -> :ok
          {:error, reason} -> Logger.error("[Retention] Failed to publish workflow deleted: #{inspect(reason)}")
        end

      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("[Retention] Failed to count pipelines for workflow: #{inspect(reason)}")
    end
  end

  defp unique_workflows(records) do
    Enum.reduce(records, %{}, fn {_, workflow_id, request_args}, acc ->
      if workflow_id && workflow_id != "" do
        Map.put_new(acc, workflow_id, request_args || %{})
      else
        acc
      end
    end)
  end

  defp extract_ids(nil), do: {nil, nil, nil}

  defp extract_ids(request_args) do
    {
      Map.get(request_args, "organization_id"),
      Map.get(request_args, "project_id"),
      Map.get(request_args, "artifact_store_id")
    }
  end
end
