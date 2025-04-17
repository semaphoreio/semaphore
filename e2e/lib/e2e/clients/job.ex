defmodule E2E.Clients.Job do
  alias E2E.Clients.Common

  @log_api_endpoint "api/v1alpha/logs"

  def events(job_id) do
    url = "#{@log_api_endpoint}/#{job_id}"

    case Common.get(url) do
      {:ok, response} ->
        case response.status_code do
          code when code in 200..299 ->
            case Jason.decode(response.body) do
              {:ok, data} -> {:ok, data["events"]}
              {:error, e} -> {:error, "Error listing events: #{inspect(e)}"}
            end

          _ ->
            {:error, response.body}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
