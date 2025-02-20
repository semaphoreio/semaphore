defmodule Block.CodeRepo do
  @moduledoc """
  Fetch file (usually pipeline definition config file) from repo
  """

  alias Block.CodeRepo.{Local, Snapshot, RepositoryAPI}
  alias Block.CodeRepo.Expand
  alias Block.{RepoHubClient, ListenerProxyClient}

  @doc ~S"""
      iex> args = %{"service" => "local", "repo_name" => "1_config_file_exists",
      ...>   "working_dir" => ".semaphore", "file_name" => "semaphore.yml"}
      iex> Block.CodeRepo.get_file(args)
      {:ok, "I'm here!\n"}
  """
  def get_file(args, wf_id \\ "") when is_map(args) do
    with service
                <- Map.get(args, "service"),
        working_dir when is_binary(working_dir)
                <- Map.get(args, "working_dir") || {:error, "missing working_dir"},
        file_name when is_binary(file_name)
                <- Map.get(args, "file_name") || {:error, "missing file_name"},
        full_file_name <- Expand.full_name(working_dir, file_name),
    do: do_get_file(service, full_file_name, args, wf_id)
  end

  def do_get_file("local", full_file_name, args, _wf_id) do
    with  repo_name when is_binary(repo_name)
                  <- Map.get(args, "repo_name", {:error, "missing repo_name"}),
    do: Local.get_file(repo_name, full_file_name, args)
  end

  def do_get_file("snapshot", full_file_name, args, _wf_id) do
    with snapshot_id <- Map.get(args, "snapshot_id") || {:error, "missing snapshot_id"},
    do: Snapshot.get_file(snapshot_id, full_file_name)
  end

  def do_get_file("listener_proxy", full_file_name, _args, wf_id) do
    {:ok, %{content: content}} = ListenerProxyClient.get_cfg(full_file_name, wf_id)

    {:ok, content}
  end

  def do_get_file(service, full_file_name, args, _wf_id) when service in ["git_hub", "bitbucket", "gitlab"] do
    with project_id <- Map.get(args, "project_id"),
         repository_id <- Map.get(args, "repository_id"),
         commit_sha <- Map.get(args, "commit_sha"),
         {:ok, repository_id} <- ensure_repository_id(repository_id, project_id),
      do: RepositoryAPI.get_file(repository_id, commit_sha, full_file_name)
  end

  def do_get_file(service, _full_file_name, _args, _wf_id) do
    {:error, "Unrecognized or missing service: #{service}"}
  end

  defp ensure_repository_id(repository_id, _) when is_binary(repository_id) and repository_id != "",
    do: {:ok, repository_id}

  defp ensure_repository_id(_, project_id), do: RepoHubClient.get_repo_id(project_id)
end
