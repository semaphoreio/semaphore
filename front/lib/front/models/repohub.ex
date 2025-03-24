defmodule Front.Models.Repohub do
  require Logger

  alias InternalApi.Repository.RepositoryService.Stub

  def fetch_semaphore_files(repository_id, initial_yaml, commit_sha \\ "", reference \\ "") do
    Watchman.benchmark("external.repohub.find_all_yaml_files.duration", fn ->
      request =
        InternalApi.Repository.GetFilesRequest.new(
          repository_id: repository_id,
          revision: InternalApi.Repository.Revision.new(
            commit_sha: commit_sha,
            reference: reference
          ),
          selectors: extract_selectors(initial_yaml),
          include_content: true
        )

      case Stub.get_files(channel(), request, timeout: 60_000) do
        {:ok, res} -> {:ok, res.files}
        e -> e
      end
    end)
  end

  def commit(request) do
    Stub.commit(channel(), request, timeout: 60_000)
  end

  def extract_selectors(initial_yaml) do
    alias InternalApi.Repository.GetFilesRequest.Selector

    case Path.dirname(initial_yaml) do
      "." ->
        [initial_yaml |> remove_prefixes()]

      "/" ->
        [initial_yaml |> remove_prefixes()]

      direcotry ->
        [
          "#{direcotry |> remove_prefixes()}/**/*.yml",
          "#{direcotry |> remove_prefixes()}/**/*.yaml"
        ]
    end
    |> Enum.map(fn selector ->
      Selector.new(glob: selector)
    end)
  end

  defp remove_prefixes(path) do
    path
    |> String.replace_prefix("/", "")
    |> String.replace_prefix("./", "")
  end

  defp channel do
    {:ok, ch} = GRPC.Stub.connect(api_endpoint())

    ch
  end

  defp api_endpoint do
    Application.fetch_env!(:front, :repohub_grpc_endpoint)
  end
end
