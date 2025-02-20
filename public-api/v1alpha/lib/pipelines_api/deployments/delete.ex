defmodule PipelinesAPI.Deployments.Delete do
  @moduledoc """
  Plug deletes a deployment target.
  """

  use Plug.Builder

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.DeploymentsClient
  alias PipelinesAPI.Pipelines.Common

  import PipelinesAPI.Deployments.Common,
    only: [get_project_id_from_target: 2, has_deployment_targets_enabled: 2]

  import PipelinesAPI.Deployments.Authorize, only: [authorize_manage_project: 2]

  alias PipelinesAPI.Util.VerifyData, as: VD

  @enabled_fields ~w(unique_token id target_id)

  plug(:verify_params)
  plug(:has_deployment_targets_enabled)
  plug(:get_project_id_from_target)
  plug(:authorize_manage_project)
  plug(:delete)

  def delete(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["dt_delete"], fn ->
      conn.params
      |> DeploymentsClient.delete(conn)
      |> Common.respond(conn)
    end)
  end

  def verify_params(conn, _otps) do
    VD.verify(
      VD.is_valid_uuid?(conn.params["unique_token"]),
      "unique_token must be a valid UUID"
    )
    |> VD.verify(
      VD.is_valid_uuid?(conn.params["id"]),
      "target_id must be a valid UUID"
    )
    |> VD.verify(
      VD.is_valid_uuid?(conn.params["target_id"]),
      "target_id must be a valid UUID"
    )
    |> VD.finalize_verification(conn, @enabled_fields)
  end
end
