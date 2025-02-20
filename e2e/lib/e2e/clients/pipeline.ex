defmodule E2E.Clients.Pipeline do
  alias E2E.Clients.Common

  @api_endpoint "api/v1alpha/pipelines"

  def list(workflow_id) do
    url = "#{@api_endpoint}?wf_id=#{workflow_id}"

    case Common.get(url) do
      {:ok, response} ->
        case response.status_code do
          code when code in 200..299 ->
            case Jason.decode(response.body) do
              {:ok, pipelines} -> {:ok, pipelines}
              {:error, e} -> {:error, "Error listing pipelines: #{inspect(e)}"}
            end

          _ ->
            {:error, response.body}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def failed_jobs_id(pipeline_id) do
    url = "#{@api_endpoint}/#{pipeline_id}?detailed=true"

    case Common.get(url) do
      {:ok, response} ->
        case response.status_code do
          code when code in 200..299 ->
            case Jason.decode(response.body) do
              {:ok, pipeline} ->
                {:ok, extract_non_passed_job_ids(pipeline)}

              {:error, e} ->
                {:error, "Error fetching pipeline: #{inspect(e)}"}
            end

          _ ->
            {:error, response.body}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_non_passed_job_ids(%{"blocks" => blocks}) do
    blocks
    |> Enum.flat_map(fn block ->
      block["jobs"]
      |> Enum.reject(fn job -> job["result"] == "PASSED" end)
      |> Enum.map(& &1["job_id"])
    end)
  end
end
