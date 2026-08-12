defmodule GithubNotifier.Status do
  alias GithubNotifier.StatusSender

  def create(nil, _request_id), do: nil

  # Every status in the list is attempted — the statuses are independent
  # GitHub contexts, so one failing must not starve the ones after it (the
  # pipeline-level status is last). Delivered ones dedupe on redelivery.
  def create(data, request_id) when is_list(data) do
    failures =
      data
      |> Enum.map(&deliver(&1, request_id))
      |> Enum.filter(&match?({:error, _}, &1))

    case failures do
      [] ->
        :ok

      failures ->
        keys = Enum.map_join(failures, ", ", fn {:error, status_key} -> status_key end)
        raise "Failed to deliver #{length(failures)} of #{length(data)} statuses: #{keys}"
    end
  end

  def create(data, request_id) do
    case deliver(data, request_id) do
      :ok -> :ok
      {:error, status_key} -> raise "Failed to deliver #{data.state} status for #{status_key}"
    end
  end

  defp deliver(nil, _request_id), do: :ok

  defp deliver(data, request_id) do
    status_key = "#{data.repository_id}/#{data.sha}/#{data.ppl_id}/#{data.context}"

    case StatusSender.send_status(status_key, data, request_id) do
      :ok -> :ok
      :error -> {:error, status_key}
    end
  end

  defp map_status("success"), do: :SUCCESS
  defp map_status("pending"), do: :PENDING
  defp map_status("failure"), do: :FAILURE
  defp map_status("stopped"), do: :STOPPED
end
