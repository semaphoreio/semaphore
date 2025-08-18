defmodule Front.Models.Artifacthub do
  defstruct [:is_directory, :resource_name, :path, :size]
  require Logger

  alias InternalApi.Artifacthub.ArtifactService.Stub
  alias InternalApi.Artifacthub.DeletePathRequest, as: DeleteRequest
  alias InternalApi.Artifacthub.GetSignedURLRequest, as: GetSignedURLRequest
  alias InternalApi.Artifacthub.ListPathRequest, as: ListRequest

  alias Front.ArtifacthubResource, as: Resource

  alias InternalApi.Artifacthub.RetentionPolicy, as: Policy
  alias InternalApi.Artifacthub.UpdateRetentionPolicyResponse

  def api_endpoint do
    Application.fetch_env!(:front, :artifacthub_api_grpc_endpoint)
  end

  def describe(project_id, include_retention_policy \\ false) do
    Watchman.benchmark("artifacthub.describe.duration", fn ->
      alias InternalApi.Artifacthub.DescribeRequest, as: Request

      with {:ok, store_id} <- get_artifact_store_id(project_id),
           request <-
             Request.new(
               artifact_id: store_id,
               include_retention_policy: include_retention_policy
             ),
           {:ok, ch} <- GRPC.Stub.connect(api_endpoint()) do
        {:ok, _res} = Stub.describe(ch, request, timeout: 30_000)
      end
    end)
  end

  @spec update_retention_policy(String.t(), Policy.t()) ::
          {:ok, UpdateRetentionPolicyResponse} | {:error, String.t()}
  def update_retention_policy(project_id, policy) do
    alias InternalApi.Artifacthub.UpdateRetentionPolicyRequest, as: Request

    Watchman.benchmark("artifacthub.update_retention_policy.duration", fn ->
      with {:ok, store_id} <- get_artifact_store_id(project_id),
           request <- Request.new(artifact_id: store_id, retention_policy: policy),
           {:ok, ch} <- GRPC.Stub.connect(api_endpoint()) do
        {:ok, _res} = Stub.update_retention_policy(ch, request, timeout: 30_000)
      end
    end)
  end

  def list(project_id, source_kind, source_id, path \\ "", unwrap_directories \\ false) do
    Watchman.benchmark("artifacthub.list_request.duration", fn ->
      with req_path <- Resource.request_path(source_kind, source_id, path),
           {:ok, store_id} <- get_artifact_store_id(project_id),
           {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
           request <-
             ListRequest.new(
               artifact_id: store_id,
               path: req_path,
               unwrap_directories: unwrap_directories
             ),
           {:ok, response} <- Stub.list_path(channel, request, timeout: 30_000),
           {:ok, artifacts} <- parse_list_response(response, source_kind, source_id, req_path) do
        {:ok, artifacts}
      else
        {:error, :non_existent_path} ->
          {:error, :non_existent_path}

        e ->
          Watchman.increment("artifacthub.list_path.failed")
          Logger.error("listing artifacts #{source_kind} failed: #{source_id}, #{inspect(e)}")

          {:error, :grpc_req_failed}
      end
    end)
  end

  def destroy(project_id, source_kind, source_id, path \\ "") do
    Watchman.benchmark("artifacthub.delete_request.duration", fn ->
      with req_path <- Resource.request_path(source_kind, source_id, path),
           {:ok, store_id} <- get_artifact_store_id(project_id),
           {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
           request <- DeleteRequest.new(artifact_id: store_id, path: req_path),
           {:ok, _response} <- Stub.delete_path(channel, request, timeout: 30_000) do
        {:ok, :path_deleted}
      else
        e ->
          Watchman.increment("artifacthub.delete_path.failed")

          Logger.error(
            "Failed to delete artifacts for: #{source_kind}:#{source_id}, #{inspect(e)}"
          )

          {:error, :grpc_req_failed}
      end
    end)
  end

  def fetch_file(store_id, source_kind, source_id, relative_path) do
    with {:ok, url} <- signed_url_with_store_id(store_id, source_kind, source_id, relative_path),
         {:ok, response} <- HTTPoison.get(url),
         %{status_code: 200, body: content} <- response do
      {:ok, content}
    else
      %{status_code: 404, body: error} -> {:error, {:not_found, error}}
      error = {:error, _e} -> error
      error -> {:error, error}
    end
  end

  def signed_url_with_store_id(store_id, source_kind, source_id, relative_path, method \\ "GET") do
    Watchman.benchmark("artifacthub.get_signed_url_request.duration", fn ->
      with req_path <- Resource.request_path(source_kind, source_id, relative_path),
           {:ok, channel} <- GRPC.Stub.connect(api_endpoint()),
           request <-
             GetSignedURLRequest.new(artifact_id: store_id, path: req_path, method: method),
           {:ok, response} <- Stub.get_signed_url(channel, request, timeout: 30_000) do
        {:ok, response.url}
      else
        e ->
          Watchman.increment("artifacthub.get_signed_url.failed")
          Logger.error("Failed to get url: #{inspect(e)}")

          {:error, :grpc_req_failed}
      end
    end)
  end

  def list_and_sign_urls(project_id, source_kind, source_id, relative_path) do
    case list(project_id, source_kind, source_id, relative_path, true) do
      {:ok, artifacts} ->
        Enum.reduce_while(artifacts, {:ok, %{}}, fn artifact, {_, urls} ->
          case signed_url(project_id, source_kind, source_id, artifact.path) do
            {:ok, url} ->
              {:cont, {:ok, Map.put(urls, artifact.path, url)}}

            e ->
              {:halt, {:error, "error generating signed URL for #{artifact.path}: #{inspect(e)}"}}
          end
        end)

      e ->
        e
    end
  end

  def signed_url(project_id, source_kind, source_id, relative_path, method \\ "GET") do
    case get_artifact_store_id(project_id) do
      {:ok, store_id} ->
        signed_url_with_store_id(store_id, source_kind, source_id, relative_path, method)

      e ->
        Watchman.increment("artifacthub.get_signed_url.failed")
        Logger.error("Failed to get url: #{inspect(e)}")

        {:error, :grpc_req_failed}
    end
  end

  defp parse_list_response(response, source_kind, source_id, path) do
    if Enum.empty?(response.items) && not Resource.root_path?(source_kind, source_id, path) do
      {:error, :non_existent_path}
    else
      artifacts =
        response.items
        |> Enum.map(fn x ->
          construct(x, source_kind, source_id)
        end)

      {:ok, artifacts}
    end
  end

  def construct(artifact_item, source_kind, source_id) do
    %__MODULE__{
      is_directory: artifact_item.is_directory,
      resource_name: Resource.get_name(artifact_item, source_kind, source_id),
      path: Resource.get_relative_path(artifact_item.name, source_kind, source_id),
      size: artifact_item.size
    }
  end

  defp get_artifact_store_id(project_id) do
    Watchman.benchmark("project-api.get_artifact_store_id.duration", fn ->
      case Front.Models.Project.find_by_id(project_id) do
        nil -> {:error, :project_describe_failed}
        project -> {:ok, project.artifact_store_id}
      end
    end)
  end
end
