defmodule RepositoryHub.UniversalAdapter do
  alias RepositoryHub.{
    UniversalAdapter,
    ProjecthubClient,
    Model
  }

  import RepositoryHub.Toolkit

  defstruct [:name, :short_name]

  @doc """
  Creates a new UniversalAdapter

  # Examples

    iex> RepositoryHub.UniversalAdapter.new()
    %RepositoryHub.UniversalAdapter{name: "Universal", short_name: "uni"}
  """
  def new do
    %UniversalAdapter{name: "Universal", short_name: "uni"}
  end

  def context(repository_id, stream) do
    with {:ok, repository} <- Model.RepositoryQuery.get_by_id(repository_id),
         {:ok, project} <- ProjecthubClient.describe(repository.project_id),
         etag <- get_etag(stream),
         {:ok, git_repository} <- Model.GitRepository.new(repository.url, repository.remote_id) do
      %{
        repository: repository,
        project: project,
        git_repository: git_repository,
        etag: etag
      }
      |> wrap()
    end
  end

  defp get_etag(nil), do: nil

  defp get_etag(stream) do
    stream
    |> GRPC.Stream.get_headers()
    |> Map.take(["if-none-match"])
    |> Map.values()
    |> List.first()
  end

  def fetch_whitelist_settings(request) do
    request.whitelist
    |> case do
      nil ->
        %{"branches" => [], "tags" => []}

      whitelist ->
        %{
          "branches" => whitelist.branches,
          "tags" => whitelist.tags
        }
    end
  end

  def fetch_commit_status(request) do
    request.commit_status
    |> case do
      %InternalApi.Projecthub.Project.Spec.Repository.Status{} = status ->
        %{
          "pipeline_files" => commit_status_pipeline_files(status.pipeline_files, request),
          "skip_scheduled_run" => status.skip_scheduled_run,
          "skip_manual_run" => status.skip_manual_run
        }

      _ ->
        %{"pipeline_files" => [%{"path" => fetch_pipeline_file(request), "level" => "pipeline"}]}
    end
  end

  defp commit_status_pipeline_files([], request),
    do: [%{"path" => fetch_pipeline_file(request), "level" => "pipeline"}]

  defp commit_status_pipeline_files(pipeline_files, _request) do
    Enum.map(pipeline_files, fn pf ->
      level =
        pf.level
        |> Atom.to_string()
        |> String.downcase()

      %{"path" => pf.path, "level" => level}
    end)
  end

  def fetch_pipeline_file(request) do
    request.pipeline_file
    |> case do
      pipeline_file when pipeline_file in ["", nil] ->
        ".semaphore/semaphore.yml"

      pipeline_file ->
        pipeline_file
    end
  end
end
