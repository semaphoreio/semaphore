defmodule Ppl.Retention.PipelineDeletionQueries do
  @moduledoc """
  Helpers for fetching and deleting expired pipelines and publishing pipeline deletion events.
  """

  import Ecto.Query

  require Logger

  alias Ppl.PplRequests.Model.PplRequests
  alias Ppl.Retention.EventPublisher

  @type repo :: module()
  @type record :: {pipeline_id :: String.t(), workflow_id :: String.t(), request_args :: map()}

  @spec fetch_expired_records(repo :: repo(), limit :: non_neg_integer()) :: [record()]
  def fetch_expired_records(repo, limit) do
    now = NaiveDateTime.utc_now()

    from(pr in PplRequests,
      where: pr.expires_at < ^now,
      select: {pr.id, pr.wf_id, pr.request_args},
      limit: ^limit,
      lock: "FOR UPDATE SKIP LOCKED"
    )
    |> repo.all()
  end

  @spec delete_blocks(records :: [record()]) :: :ok
  def delete_blocks(records) do
    records
    |> Enum.map(&elem(&1, 0))
    |> Enum.each(&Block.delete_blocks_from_ppl/1)

    :ok
  end

  @spec delete_pipelines(repo :: repo(), records :: [record()]) :: {:ok, non_neg_integer()}
  def delete_pipelines(repo, records) do
    ids = Enum.map(records, &elem(&1, 0))

    if ids == [] do
      {:ok, 0}
    else
      {count, _} =
        from(pr in PplRequests, where: pr.id in ^ids)
        |> repo.delete_all()

      {:ok, count}
    end
  end

  @spec publish_pipeline_deleted(records :: [record()]) :: :ok
  def publish_pipeline_deleted(records) do
    Enum.each(records, fn {pipeline_id, workflow_id, request_args} ->
      {org_id, project_id, artifact_store_id} = request_args_fields(request_args)

      case EventPublisher.publish_pipeline_deleted(
             pipeline_id,
             workflow_id,
             org_id,
             project_id,
             artifact_store_id
           ) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error(
            "Failed to publish pipeline deleted event for #{pipeline_id}/#{workflow_id}: #{inspect(reason)}"
          )
      end
    end)

    :ok
  end

  defp request_args_fields(request_args) do
    args = request_args || %{}
    {Map.get(args, "organization_id"), Map.get(args, "project_id"),
     Map.get(args, "artifact_store_id")}
  end
end
