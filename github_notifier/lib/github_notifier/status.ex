defmodule GithubNotifier.Status do
  alias GithubNotifier.StatusSender

  def create(nil, _request_id), do: nil

  def create(data, request_id) when is_list(data) do
    Enum.each(data, fn x -> create(x, request_id) end)
  end

  def create(data, request_id) do
    status_key = "#{data.repository_id}/#{data.sha}/#{data.ppl_id}/#{data.context}"

    case StatusSender.send_status(status_key, data, request_id) do
      :ok -> :ok
      :error -> raise "Failed to deliver #{data.state} status for #{status_key}"
    end
  end
end
