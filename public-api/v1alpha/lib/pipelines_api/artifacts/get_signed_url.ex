defmodule PipelinesAPI.Artifacts.GetSignedURL do
  @moduledoc """
  Plug endpoint for generating artifacts signed URLs through v1alpha API.
  """

  use Plug.Builder

  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.ToTuple
  alias PipelinesAPI.Util.Metrics

  import PipelinesAPI.Artifacts.Authorize, only: [authorize_signed_url: 2]

  import PipelinesAPI.Artifacts.Common,
    only: [
      apply_optional_limit: 2,
      build_page: 3,
      get_artifact_store_id: 2,
      normalize_optional_limit: 1,
      validate_request_params: 3,
      resolve_project_id_from_scope: 2
    ]

  @enabled_fields ~w(scope scope_id path method limit)

  plug(:verify_params)
  plug(:resolve_project_id_from_scope)
  plug(:authorize_signed_url)
  plug(:get_artifact_store_id)
  plug(:get_signed_url)

  def get_signed_url(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["artifacts_signed_url"], fn ->
      result =
        conn.params
        |> gather_signed_urls()
        |> format_response(conn.params)

      maybe_track_lookup_failure(result)
      RespCommon.respond(result, conn)
    end)
  end

  def verify_params(conn, _opts) do
    conn
    |> validate_request_params(@enabled_fields, require_path: true, validate_method: true)
    |> normalize_optional_limit()
  end

  defp maybe_track_lookup_failure({:error, _}) do
    Metrics.increment("PipelinesAPI.router", ["artifacts_signed_url_lookup_failed"])
  end

  defp maybe_track_lookup_failure(_result), do: :ok

  defp gather_signed_urls(params) do
    case ArtifactHubClient.get_signed_url(params) do
      {:ok, %{url: url}} ->
        {:ok, %{items: [%{path: params["path"], url: url}], total: 1}}

      {:error, {:not_found, _}} ->
        gather_directory_signed_urls(params)

      error ->
        error
    end
  end

  defp gather_directory_signed_urls(%{"method" => method}) when method != "GET" do
    ToTuple.user_error("method must be GET when path points to a directory")
  end

  defp gather_directory_signed_urls(params) do
    with {:ok, artifacts} <- list_directory_files(params),
         total <- length(artifacts),
         limited_artifacts <- apply_optional_limit(artifacts, params["limit"]),
         {:ok, signed_items} <- sign_directory_files(limited_artifacts, params) do
      {:ok, %{items: signed_items, total: total}}
    end
  end

  defp list_directory_files(params) do
    params
    |> Map.put("unwrap_directories", true)
    |> ArtifactHubClient.list_path()
    |> convert_directory_not_found()
    |> extract_file_artifacts()
  end

  defp convert_directory_not_found({:error, {:not_found, _}}) do
    ToTuple.not_found_error("Artifact not found")
  end

  defp convert_directory_not_found(result), do: result

  defp extract_file_artifacts({:ok, artifacts}) do
    artifacts
    |> Enum.reject(&Map.get(&1, :is_directory, false))
    |> sort_artifacts()
    |> ToTuple.ok()
  end

  defp extract_file_artifacts(error), do: error

  defp sign_directory_files(artifacts, params) do
    artifacts
    |> Enum.reduce_while({:ok, []}, fn artifact, {:ok, signed_items} ->
      case sign_single_file(artifact.path, params) do
        {:ok, signed_item} ->
          {:cont, {:ok, [signed_item | signed_items]}}

        error ->
          {:halt, error}
      end
    end)
    |> reverse_signed_items()
  end

  defp sign_single_file(path, params) do
    params
    |> Map.put("path", path)
    |> Map.put("method", "GET")
    |> ArtifactHubClient.get_signed_url()
    |> to_signed_item(path)
  end

  defp to_signed_item({:ok, %{url: url}}, path), do: {:ok, %{path: path, url: url}}
  defp to_signed_item(error, _path), do: error

  defp reverse_signed_items({:ok, signed_items}), do: {:ok, Enum.reverse(signed_items)}
  defp reverse_signed_items(error), do: error

  defp format_response({:ok, %{items: items, total: total}}, params) do
    limit = Map.get(params, "limit")
    returned = length(items)

    {:ok,
     %{
       items: items,
       page: build_page(limit, returned, total)
     }}
  end

  defp format_response(error, _params), do: error

  defp sort_artifacts(artifacts) do
    Enum.sort_by(artifacts, fn artifact ->
      artifact
      |> Map.get(:path, "")
      |> to_string()
    end)
  end
end
