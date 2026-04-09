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
    items =
      urls
      |> Enum.map(&signed_item(&1, params))

    {:ok, %{items: items}}
  end

  defp process_signed_urls({:error, {:not_found, _}}, _params) do
    ToTuple.not_found_error("Artifact not found")
  end

  defp process_signed_urls(error, _params), do: error

  defp signed_item(%{url: url}, params) do
    %{
      path: path_from_signed_url(url, params),
      url: url
    }
  end

  defp path_from_signed_url(url, params) do
    scope = Map.get(params, "scope", "")
    scope_id = Map.get(params, "scope_id", "")
    requested_path = Map.get(params, "path", "")
    marker = "artifacts/#{scope}/#{scope_id}/"

    url
    |> URI.parse()
    |> Map.get(:path, "")
    |> to_string()
    |> URI.decode()
    |> String.trim_leading("/")
    |> extract_relative_path(marker)
    |> case do
      nil -> requested_path
      parsed_path -> normalize_parsed_path(parsed_path, requested_path)
    end
  end

  defp extract_relative_path("", _marker), do: nil

  defp extract_relative_path(path, marker) do
    case String.split(path, marker, parts: 2) do
      [_prefix, relative_path] when relative_path != "" -> relative_path
      _ -> path
    end
  end

  defp normalize_parsed_path(parsed_path, requested_path) do
    cond do
      parsed_path == "" ->
        requested_path

      String.contains?(parsed_path, "/") ->
        parsed_path

      String.contains?(requested_path, "/") ->
        requested_path

      true ->
        parsed_path
    end
  end

  defp format_response({:ok, %{items: items}}, _params), do: {:ok, %{items: items}}

  defp format_response(error, _params), do: error
end
