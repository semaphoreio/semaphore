defmodule PipelinesAPI.PreFlightChecks.Describe do
  @moduledoc """
  Plug which returns pre-flight checks configuration for the organization,
  or for a single project when project_id is given.
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.PreFlightChecksClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Util.VerifyData, as: VD

  import PipelinesAPI.PreFlightChecks.Common, only: [has_pre_flight_checks_enabled: 2]

  import PipelinesAPI.PreFlightChecks.Authorize, only: [authorize_view: 2]

  @enabled_fields ~w(project_id)

  plug(:verify_params)
  plug(:has_pre_flight_checks_enabled)
  plug(:authorize_view)
  plug(:describe_pre_flight_checks)

  def describe_pre_flight_checks(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["pfc_describe"], fn ->
      conn.params
      |> PreFlightChecksClient.describe(conn)
      |> RespCommon.respond(conn)
    end)
  end

  def verify_params(conn, _otps) do
    VD.verify(
      VD.is_valid_uuid?(conn.params["project_id"]),
      "project_id must be a valid UUID"
    )
    |> VD.finalize_verification(conn, @enabled_fields)
  end
end
