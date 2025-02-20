defmodule Block.CodeRepo.RepositoryAPI do
  @moduledoc """
  Get file from RepositoryAPI service (former RepoHub).
  """

  def get_file(repository_id, commit_sha, file_path) do
    Block.RepoHubClient.get_file(repository_id, commit_sha, file_path)
    |> handle_response(file_path)
  end

  defp handle_response(response = {:ok, _content}, _), do: response
  defp handle_response({:error, {:malformed, message}}, file_name) do
    msg = "File '#{file_name}' is not available"
    {:error, {:malformed, {msg, message}}}
  end
  defp handle_response(error = {:error, _message}, _), do: error
end
