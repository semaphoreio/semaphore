defmodule Block.CodeRepo.Snapshot do
  @moduledoc """
  Get file from snapshot repo.
  """

  alias InternalApi.Paparazzo.GetFileRequest
  alias InternalApi.Paparazzo.SnapshotService.Stub
  alias Google.Rpc.Code

  def get_file(snapshot_id, path) do
    snapshot_id
    |> do_get_file(path)
    |> response_handler(snapshot_id, path)
  end

  def do_get_file(snapshot_id, path) do
    {:ok, channel} = GRPC.Stub.connect(paparazzo_url())
    request = %GetFileRequest{id: snapshot_id, path: path}
    {:ok, response} = channel |> Stub.get_file(request)
    response
  end

  defp response_handler(response, snapshot_id, path) do
    cond do
      response.status.code == Code.value(:OK) ->
        {:ok, response.content}
      response.status.code == Code.value(:NOT_FOUND) ->
        {:error, {:malformed, "snapshot_id: '#{snapshot_id}', pathfile '#{path}': #{response.status.message} "}}
      true ->
        {:error, response}
    end
  end

  defp paparazzo_url, do: System.get_env("PAPARAZZO_URL")
end
