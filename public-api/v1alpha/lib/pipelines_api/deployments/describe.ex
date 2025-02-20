defmodule PipelinesAPI.Deployments.Describe do
  @moduledoc """
  Plug describes a deployment target.
  """

  use Plug.Builder

  alias PipelinesAPI.Deployments.Secrets
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.DeploymentsClient
  alias PipelinesAPI.Pipelines.Common

  import PipelinesAPI.Deployments.Common,
    only: [get_project_id_from_target: 2, has_deployment_targets_enabled: 2]

  import PipelinesAPI.Deployments.Authorize, only: [authorize_view_project: 2]

  alias PipelinesAPI.Util.VerifyData, as: VD

  @enabled_fields ~w(id target_id project_id include_secrets)

  plug(:verify_params)
  plug(:has_deployment_targets_enabled)
  plug(:get_project_id_from_target)
  plug(:authorize_view_project)
  plug(:describe)

  def describe(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["dt_describe"], fn ->
      conn.params
      |> DeploymentsClient.describe()
      |> Secrets.describe_targets_secrets(conn)
      |> Common.respond(conn)
    end)
  end

  def verify_params(conn, _otps) do
    VD.verify(
      VD.is_valid_uuid?(conn.params["id"]),
      "id must be a valid UUID"
    )
    |> VD.verify(
      VD.is_valid_uuid?(conn.params["target_id"]),
      "target_id must be a valid UUID"
    )
    |> VD.verify(
      VD.is_valid_uuid?(conn.params["project_id"]),
      "project id must be a valid UUID"
    )
    |> VD.finalize_verification(conn, @enabled_fields)
  end
end
