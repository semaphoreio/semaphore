defmodule Front.ActivityMonitor.Actions do
  alias Front.RBAC.Permissions
  alias InternalApi.Plumber.TerminateRequest
  alias InternalApi.ServerFarm.Job.StopRequest
  alias Util.Proto

  @type stop_response ::
          :ok
          | {:error, :bad_request, String.t()}
          | {:error, :forbidden, String.t()}
          | {:error, :not_found, String.t()}
          | {:error, :unknown, String.t()}

  @spec stop(String.t(), String.t(), String.t(), String.t()) :: stop_response()
  def stop(org_id, user_id, item_type, item_id) do
    cond do
      !Front.ActivityMonitor.valid_item_type?(item_type) ->
        {:error, :bad_request, "Unknown Item Type '#{item_type}'"}

      item_type == "Pipeline" ->
        item_id |> Front.Models.Pipeline.find_metadata() |> stop_pipeline(org_id, user_id)

      item_type == "Debug Session" ->
        item_id |> Front.Models.Job.find() |> stop_job(org_id, user_id)
    end
  end

  defp stop_pipeline(ppl = %{}, org_id, user_id) do
    if Permissions.has?(user_id, org_id, ppl.project_id, "project.job.stop") do
      stop_pipeline_(user_id, ppl.id)
    else
      {:error, :forbidden, "Not authorized"}
    end
  end

  defp stop_pipeline(error, _org_id, _user_id),
    do: {:error, :unknown, "Unknown response: #{inspect(error)}"}

  defp stop_pipeline_(user_id, ppl_id) do
    %{
      ppl_id: ppl_id,
      requester_id: user_id
    }
    |> Proto.deep_new!(TerminateRequest)
    |> Front.Clients.Pipeline.terminate()
    |> parse_response(ppl_id)
  end

  defp stop_job(job = %{}, org_id, user_id) do
    if Permissions.has?(user_id, org_id, job.project_id, "project.job.stop") do
      stop_job_(user_id, job.id)
    else
      {:error, :forbidden, "Not authorized"}
    end
  end

  defp stop_job(error, _org_id, _user_id),
    do: {:error, :unknown, "Unknown response: #{inspect(error)}"}

  defp stop_job_(user_id, job_id) do
    %{
      job_id: job_id,
      requester_id: user_id
    }
    |> Proto.deep_new!(StopRequest)
    |> Front.ActivityMonitor.Repo.stop_job()
    |> parse_response(job_id)
  end

  defp parse_response({_atom, response}, id) do
    response |> Proto.to_map!() |> parse_response_(id)
  end

  defp parse_response_(%{response_status: %{code: :OK}}, _ppl_id), do: :ok

  defp parse_response_(%{response_status: %{code: :BAD_PARAM}}, ppl_id),
    do: {:error, :not_found, "Pipeline with id #{ppl_id} not found."}

  defp parse_response_(%{status: %{code: :OK}}, _job_id), do: :ok

  defp parse_response_(%{status: %{code: :BAD_PARAM}}, job_id),
    do: {:error, :not_found, "Job with id #{job_id} not found."}

  defp parse_response_(response, item_id),
    do: {:error, :unknown, "Unknown response type for item #{item_id}: #{inspect(response)}"}
end
