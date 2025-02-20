defmodule Gofer.RepoHubClient do
  @moduledoc """
  Calls RepoHub(Repository) API
  """

  alias Util.{Metrics, Proto, ToTuple}
  alias LogTee, as: LT

  alias InternalApi.Repository.{
    RepositoryService,
    ListRequest,
    GetChangedFilePathsRequest
  }

  defp url(), do: System.get_env("REPOHUB_GRPC_URL")
  @opts [{:timeout, 5_500_000}]

  @doc """
  Uses List API call to get repository_id
  """
  def get_repo_id(project_id) do
    result =
      Wormhole.capture(__MODULE__, :get_repo_id_, [project_id], stacktrace: true, timeout: 3_000)

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def get_repo_id_(project_id) do
    Metrics.benchmark("Gofer.RepoHubClient.list", fn ->
      request = ListRequest.new(project_id: project_id)
      {:ok, channel} = GRPC.Stub.connect(url())

      channel
      |> RepositoryService.Stub.list(request, @opts)
      |> extract_repo_id(project_id)
    end)
  end

  defp extract_repo_id({:ok, %{repositories: repos}}, _)
       when is_list(repos) and length(repos) > 0 do
    repos |> Enum.at(0) |> Map.get(:id) |> ToTuple.ok()
  end

  defp extract_repo_id({:ok, %{repositories: []}}, project_id),
    do: {:error, "There are no repositories for project #{project_id}"}

  defp extract_repo_id({:error, %GRPC.RPCError{message: message}}, _project_id),
    do: {:error, message}

  defp extract_repo_id(error, _project_id), do: {:error, error}

  @doc """
  Returns changed files in given commit range
  """
  def get_changes(params) do
    result =
      Wormhole.capture(__MODULE__, :get_changes_, [params], stacktrace: true, timeout: 10_000)

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def get_changes_(params) do
    Metrics.benchmark("Gofer.RepoHubClient.get_changes", fn ->
      with {:ok, request} <- Proto.deep_new(params, GetChangedFilePathsRequest),
           {:ok, channel} <- GRPC.Stub.connect(url()) do
        channel
        |> RepositoryService.Stub.get_changed_file_paths(request, @opts)
        |> extract_changes(params)
      end
    end)
  end

  defp extract_changes({:ok, %{changed_file_paths: changes}}, request) do
    changes |> log_if_empty(request) |> ToTuple.ok()
  end

  defp extract_changes({:error, %GRPC.RPCError{message: message}}, _req), do: {:error, message}
  defp extract_changes(error, _req), do: {:error, error}

  defp log_if_empty([], request) do
    request
    |> LT.warn("Repohub responded with empty list for this changed_file_paths request")

    []
  end

  defp log_if_empty(changes, _request), do: changes
end
