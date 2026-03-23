defmodule PipelinesAPI.Artifacts.GetSignedURL do
  @moduledoc """
  Plug endpoint for generating artifacts signed URLs through v1alpha API.
  """

  use Plug.Builder

  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics

  import PipelinesAPI.Artifacts.Authorize, only: [authorize_view: 2]

  import PipelinesAPI.Artifacts.Common,
    only: [
      get_artifact_store_id: 2,
      validate_request_params: 3,
      resolve_project_id_from_scope: 2
    ]

  @enabled_fields ~w(scope scope_id path method)

  plug(:verify_params)
  plug(:resolve_project_id_from_scope)
  plug(:authorize_view)
  plug(:get_artifact_store_id)
  plug(:get_signed_url)

  def get_signed_url(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["artifacts_signed_url"], fn ->
      result =
        conn.params
        |> ArtifactHubClient.get_signed_url()

      maybe_track_lookup_failure(result)
      RespCommon.respond(result, conn)
    end)
  end

  def verify_params(conn, _opts) do
    validate_request_params(conn, @enabled_fields, require_path: true, validate_method: true)
  end

  defp maybe_track_lookup_failure({:error, _}) do
    Metrics.increment("PipelinesAPI.router", ["artifacts_signed_url_lookup_failed"])
  end

  defp maybe_track_lookup_failure(_result), do: :ok
end
