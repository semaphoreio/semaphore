defmodule Projecthub.Analysis do
  @moduledoc """
  Analyses the repository for known structures and files. Based on the analysis,
  we can figure out the primary programming language, the dependencies used,
  and the databases needed for running this project.

  Based on this information, we can provide a customized experience for the
  customer and prepare pipelines that could theoretically work out of the box.
  """

  require Logger

  @doc """
  Returns a map with information about every topic of interest, for example: Docker.

  Every topic is a map that contains additional information about it.
  """
  def run(repository) do
    Watchman.benchmark("analyze.duration", fn ->
      {:ok, files} = get_files_of_interests(repository)

      report = %{
        "semaphore_yaml" => analyze_semaphore_yaml(files),
        "ruby" => analyze_ruby(files),
        "python" => analyze_python(files),
        "node" => analyze_node(files),
        "docker" => analyze_docker(files)
      }

      {:ok, report}
    end)
  end

  def analyze_docker(files) do
    found = Enum.any?(files, fn f -> f.path == "Dockerfile" end)

    %{"found" => found}
  end

  def analyze_semaphore_yaml(files) do
    found = Enum.any?(files, fn f -> f.path == ".semaphore/semaphore.yml" end)

    %{"found" => found}
  end

  def analyze_ruby(files) do
    found = Enum.any?(files, fn f -> f.path == "Gemfile" || f.path == "Gemfile.lock" end)

    %{"found" => found}
  end

  def analyze_python(files) do
    found = Enum.any?(files, fn f -> f.path == "requirements.txt" end)

    %{"found" => found}
  end

  def analyze_node(files) do
    found = Enum.any?(files, fn f -> f.path == "package.json" end)

    %{"found" => found}
  end

  def get_files_of_interests(repository) do
    alias InternalApi.Repository.GetFilesRequest.Selector
    alias InternalApi.Repository.RepositoryService.Stub

    Watchman.benchmark("external.repohub.get_files.duration", fn ->
      selectors = [
        # Figure out if there are some YAML files already in this repo.
        Selector.new(glob: ".semaphore/**/*"),

        # Ruby projects
        Selector.new(glob: "Gemfile"),
        Selector.new(glob: "Gemfile.lock"),

        # Node.js projects
        Selector.new(glob: "package.json"),

        # Go projects
        Selector.new(glob: "go.mod"),
        Selector.new(glob: "go.sum"),

        # Python projects
        Selector.new(glob: "requirements.txt"),

        # Docker
        Selector.new(glob: "Dockerfile"),
        Selector.new(glob: "docker-compose.yml")
      ]

      request =
        InternalApi.Repository.GetFilesRequest.new(
          repository_id: repository.id,
          revision: InternalApi.Repository.Revision.new(reference: "master"),
          include_content: false,
          selectors: selectors
        )

      case Stub.get_files(channel(), request, timeout: 60_000) do
        {:ok, res} ->
          {:ok, res.files}

        e ->
          Logger.error("Failed to retrieve files from the repository #{repository.id}")
          e
      end
    end)
  end

  defp channel do
    {:ok, ch} =
      GRPC.Stub.connect(api_endpoint(),
        interceptors: [
          Projecthub.Util.GRPC.ClientRequestIdInterceptor,
          Projecthub.Util.GRPC.ClientLoggerInterceptor,
          Projecthub.Util.GRPC.ClientRunAsyncInterceptor
        ]
      )

    ch
  end

  defp api_endpoint do
    Application.fetch_env!(:projecthub, :repohub_grpc_endpoint)
  end
end
