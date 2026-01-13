defmodule Ppl.Retention.WorkflowDeletionQueries do
  @moduledoc """
  Helpers for publishing workflow deletion events after pipeline cleanup.
  """

  require Logger

  alias Ppl.PplRequests.Model.PplRequestsQueries
  alias Ppl.Retention.EventPublisher

  @type record :: {pipeline_id :: String.t(), workflow_id :: String.t(), request_args :: map()}

  @spec publish_workflow_deleted(records :: [record()]) :: :ok
  def publish_workflow_deleted(records) do
    records
    |> workflow_candidates()
    |> Enum.each(fn {workflow_id, request_args} ->
      case PplRequestsQueries.count_pipelines_in_workflow(workflow_id) do
        {:ok, 0} ->
          {org_id, project_id, artifact_store_id} = request_args_fields(request_args)

          case EventPublisher.publish_workflow_deleted(
                 workflow_id,
                 org_id,
                 project_id,
                 artifact_store_id
               ) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.error(
                "Failed to publish workflow deleted event for #{workflow_id}: #{inspect(reason)}"
              )
          end

        {:ok, _count} ->
          :ok

        {:error, reason} ->
          Logger.error(
            "Failed to count pipelines for workflow #{workflow_id}: #{inspect(reason)}"
          )
      end
    end)

    :ok
  end

  defp workflow_candidates(records) do
    Enum.reduce(records, %{}, fn {_, workflow_id, request_args}, acc ->
      if is_nil(workflow_id) or workflow_id == "" do
        acc
      else
        Map.put_new(acc, workflow_id, request_args || %{})
      end
    end)
  end

  defp request_args_fields(request_args) do
    args = request_args || %{}
    {Map.get(args, "organization_id"), Map.get(args, "project_id"),
     Map.get(args, "artifact_store_id")}
  end
end
