defmodule Block.RepoHubClient do
  @moduledoc """
  Calls RepoHub(Repository) API
  """

  alias Util.{Metrics, Proto, ToTuple}
  alias InternalApi.Repository.{
    RepositoryService,
    DescribeManyRequest,
    GetChangedFilePathsRequest,
    GetFileRequest,
  }

  require Logger

  defp url(), do: System.get_env("INTERNAL_API_URL_REPOSITORY")
  @opts [{:timeout, 2_500_000}]

  @doc """
  Returns content of the file on the given path in the repository for given commit
  """
  def get_file(repository_id, commit_sha, file_path) do
    params = [repository_id, commit_sha, file_path]
    result =  Wormhole.capture(__MODULE__, :get_file_, params, stacktrace: true)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def get_file_(repo_id, commit_sha, file_path) do
    Metrics.benchmark("Ppl.RepoHubClient.get_file", fn ->
      {:ok, request} =
        %{repository_id: repo_id, commit_sha: commit_sha, path: file_path}
        |> Proto.deep_new(GetFileRequest)

      {:ok, channel} = GRPC.Stub.connect(url())

      Logger.info("Getting file with request: #{inspect(request)}")
      response = channel
      |> RepositoryService.Stub.get_file(request, @opts)

      Logger.info("File response: #{inspect(response)}")

      response
      |> file_response_to_map()
      |> extract_content()
    end)
  end

  defp extract_content({:ok, %{file: %{content: content}}}) do
    case content |> Base.decode64() do
      :error -> {:error, {:malformed, "Invalid content encoding."}}
      {:ok, result} -> {:ok, result}
    end
  end
  defp extract_content(error = {:error, _msg}), do: error
  defp extract_content(error), do: {:error, error}

  defp file_response_to_map({:ok, response}), do: response |> Proto.to_map()
  defp file_response_to_map({:error, %GRPC.RPCError{status: 5, message: msg}}),
    do: {:error, {:malformed, msg}}
  defp file_response_to_map({:error, %GRPC.RPCError{message: msg}}), do: {:error, msg}
  defp file_response_to_map(error = {:error, _msg}), do: error
  defp file_response_to_map(error), do: {:error, error}

  @doc """
  Uses DescribeMany API call to get repository_id
  """
  def get_repo_id(project_id) do
    result =  Wormhole.capture(__MODULE__, :get_repo_id_, [project_id],
                               stacktrace: true, timeout: 3_000)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def get_repo_id_(project_id) do
    Metrics.benchmark("Ppl.RepoHubClient.list", fn ->
      request = DescribeManyRequest.new(project_ids: [project_id])
      Logger.info("Describing many with request: #{inspect(request)}")
      {:ok, channel} = GRPC.Stub.connect(url())

      response = channel
      |> RepositoryService.Stub.describe_many(request, @opts)

      Logger.info("Response: #{inspect(response)}")

      response
      |> response_to_map()
      |> extract_repo_id(project_id)
    end)
  end

  defp extract_repo_id({:ok, %{repositories: repos}}, _)
   when is_list(repos) and length(repos) > 0 do
     repos |> Enum.at(0) |> Map.get(:id) |> ToTuple.ok()
  end
  defp extract_repo_id({:ok, %{repositories: []}}, project_id),
    do: {:error, "There are no repositories for project #{project_id}"}
  defp extract_repo_id(error = {:error, _msg}, _project_id), do: error
  defp extract_repo_id(error, _project_id), do: {:error, error}

  @doc """
  Returns changed files in given commit range
  """
  def get_changes(params) do
    result =  Wormhole.capture(__MODULE__, :get_changes_, [params],
                               stacktrace: true, timeout: 3_000)
    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def get_changes_(params) do
    Metrics.benchmark("Ppl.RepoHubClient.get_changes", fn ->
      {:ok, request} = params |> Proto.deep_new(GetChangedFilePathsRequest)
      {:ok, channel} = GRPC.Stub.connect(url())

      response = channel
      |> RepositoryService.Stub.get_changed_file_paths(request, @opts)

      Logger.info("Response: #{inspect(response)}")

      response
      |> response_to_map()
      |> extract_changes()
    end)
  end

  defp extract_changes({:ok, %{changed_file_paths: changes}}), do: {:ok, changes}
  defp extract_changes(error = {:error, _msg}), do: error
  defp extract_changes(error), do: {:error, error}

  # Utility

  defp response_to_map({:ok, response}), do: response |> Proto.to_map()
  defp response_to_map({:error, %GRPC.RPCError{message: msg}}) when msg in [2, 14],
   do: {:error, {:malformed, msg}}
  defp response_to_map({:error, %GRPC.RPCError{message: msg}}), do: {:error, msg}
  defp response_to_map(error = {:error, _msg}), do: error
  defp response_to_map(error), do: {:error, error}
end
