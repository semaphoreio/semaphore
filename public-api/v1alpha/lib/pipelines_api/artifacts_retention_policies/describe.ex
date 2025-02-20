defmodule PipelinesAPI.ArtifactsRetentionPolicy.Describe do
  @moduledoc """
  Plug which returns description of artifacts retention policies
  for a given project.
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.ArtifactHubClient
  alias PipelinesAPI.Util.VerifyData, as: VD

  import PipelinesAPI.ArtifactsRetentionPolicy.Common,
    only: [get_artifact_store_id: 2]

  import PipelinesAPI.ArtifactsRetentionPolicy.Authorize,
    only: [authorize_view_retention_policy: 2]

  @enabled_fields ~w(project_id)

  plug(:verify_params)
  plug(:authorize_view_retention_policy)
  plug(:get_artifact_store_id)
  plug(:describe_retention_policy)

  def describe_retention_policy(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["retention_describe"], fn ->
      conn.params
      |> ArtifactHubClient.describe_retention_policy()
      |> RespCommon.respond(conn)
    end)
  end

  def verify_params(conn, _otps) do
    VD.verify(
      VD.is_present_string?(conn.params["project_id"]),
      "project_id must be present"
    )
    |> VD.verify(
      VD.is_valid_uuid?(conn.params["project_id"]),
      "project id must be a valid UUID"
    )
    |> VD.finalize_verification(conn, @enabled_fields)
  end
end
