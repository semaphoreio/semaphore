defmodule PipelinesAPI.Artifacts.List do
  @moduledoc """
  Plug endpoint for listing artifacts through v1alpha API.
  """

  use Plug.Builder

  alias PipelinesAPI.Audit
  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.{Metrics, RequestMetrics}

  import PipelinesAPI.Artifacts.Authorize, only: [authorize_list: 2]

  import PipelinesAPI.Artifacts.Common,
    only: [
      has_artifacts_api_enabled: 2,
      get_artifact_store_id: 2,
      validate_request_params: 3,
      resolve_project_id_from_scope: 2
    ]

  @enabled_fields ~w(scope scope_id path)

  plug(:track_request_metrics)
  plug(:verify_params)
  plug(:has_artifacts_api_enabled)
  plug(:resolve_project_id_from_scope)
  plug(:authorize_list)
  plug(:get_artifact_store_id)
  plug(:list_artifacts)

  def track_request_metrics(conn, _opts) do
    RequestMetrics.track_request(conn, "artifacts_list_api_request")
  end

  def list_artifacts(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["artifacts_list"], fn ->
      Audit.log_artifact_list(conn, conn.params)

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
  end

  defp format_response({:ok, artifacts}, _params) do
    {:ok,
     %{
       artifacts: artifacts
     }}
  end

  defp format_response(error, _params), do: error

  defp maybe_track_lookup_failure({:error, _}) do
    Metrics.increment("PipelinesAPI.router", ["artifacts_list_lookup_failed"])
  end

  defp maybe_track_lookup_failure(_result), do: :ok
end
