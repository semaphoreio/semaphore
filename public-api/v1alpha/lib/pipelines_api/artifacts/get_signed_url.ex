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
      get_artifact_store_id: 2,
      validate_request_params: 3,
      resolve_project_id_from_scope: 2
    ]

  @enabled_fields ~w(scope scope_id path method)

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
  end

  defp maybe_track_lookup_failure({:error, _}) do
    Metrics.increment("PipelinesAPI.router", ["artifacts_signed_url_lookup_failed"])
  end

  defp maybe_track_lookup_failure(_result), do: :ok

  defp gather_signed_urls(params) do
    params
    |> ArtifactHubClient.get_signed_urls()
    |> process_signed_urls(params)
  end

  defp process_signed_urls({:ok, %{urls: []}}, _params) do
    ToTuple.not_found_error("Artifact not found")
  end

  defp process_signed_urls({:ok, %{urls: urls}}, params) do
    urls
    |> build_signed_items(params)
    |> case do
      {:ok, items} -> {:ok, %{items: items}}
      error -> error
    end
  end

  defp process_signed_urls({:error, {:not_found, _}}, _params) do
    ToTuple.not_found_error("Artifact not found")
  end

  defp process_signed_urls(error, _params), do: error

  defp build_signed_items(urls, params) do
    result =
      urls
      |> Enum.reduce_while({:ok, []}, fn signed_url, {:ok, items} ->
        case signed_item(signed_url, params) do
          {:ok, item} -> {:cont, {:ok, [item | items]}}
          error -> {:halt, error}
        end
      end)

    case result do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      error -> error
    end
  end

  defp signed_item(%{url: url}, params) do
    case path_from_signed_url(url, params) do
      {:ok, path} ->
        {:ok, %{path: path, url: url}}

      {:error, {:not_found, _reason}} ->
        ToTuple.not_found_error("Artifact not found")

      {:error, _reason} ->
        ToTuple.internal_error("Internal error")
    end
  end

  defp path_from_signed_url(url, params) do
    scope = Map.get(params, "scope", "")
    scope_id = Map.get(params, "scope_id", "")
    marker = "/artifacts/#{scope}/#{scope_id}/"

    case URI.parse(url) do
      %{path: path} when is_binary(path) and path != "" ->
        path
        |> URI.decode()
        |> normalize_url_path()
        |> extract_relative_path(marker)

      _ ->
        ToTuple.internal_error("Invalid signed URL path")
    end
  end

  defp normalize_url_path(path), do: "/" <> String.trim_leading(path, "/")

  defp extract_relative_path(path, marker) do
    case String.split(path, marker, parts: 2) do
      [_prefix, relative_path] when relative_path != "" ->
        {:ok, String.trim(relative_path, "/")}

      [_prefix, ""] ->
        ToTuple.not_found_error("Artifact not found")

      _ ->
        ToTuple.internal_error("Invalid signed URL path")
    end
  end

  defp format_response({:ok, %{items: items}}, _params), do: {:ok, %{items: items}}

  defp format_response(error, _params), do: error
end
