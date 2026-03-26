defmodule PipelinesAPI.Artifacts.List do
  @moduledoc """
  Plug endpoint for listing artifacts through v1alpha API.
  """

  use Plug.Builder

  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics

  import PipelinesAPI.Artifacts.Authorize, only: [authorize_list: 2]

  import PipelinesAPI.Artifacts.Common,
    only: [
      apply_optional_limit: 2,
      build_page: 3,
      get_artifact_store_id: 2,
      normalize_optional_limit: 1,
      validate_request_params: 3,
      resolve_project_id_from_scope: 2
    ]

  @enabled_fields ~w(scope scope_id path limit)

  plug(:verify_params)
  plug(:resolve_project_id_from_scope)
  plug(:authorize_list)
  plug(:get_artifact_store_id)
  plug(:list_artifacts)

  def list_artifacts(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["artifacts_list"], fn ->
      result =
        conn.params
        |> ArtifactHubClient.list_path()
        |> format_response(conn.params)

      maybe_track_lookup_failure(result)
      RespCommon.respond(result, conn)
    end)
  end

  def verify_params(conn, _opts) do
    conn
    |> validate_request_params(@enabled_fields, [])
    |> normalize_optional_limit()
  end

  defp format_response({:ok, artifacts}, params) do
    limit = Map.get(params, "limit")
    sorted_artifacts = sort_artifacts(artifacts)
    limited_artifacts = apply_optional_limit(sorted_artifacts, limit)
    returned = length(limited_artifacts)
    total = length(sorted_artifacts)

    {:ok,
     %{
       artifacts: limited_artifacts,
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

  defp maybe_track_lookup_failure({:error, _}) do
    Metrics.increment("PipelinesAPI.router", ["artifacts_list_lookup_failed"])
  end

  defp maybe_track_lookup_failure(_result), do: :ok
end
