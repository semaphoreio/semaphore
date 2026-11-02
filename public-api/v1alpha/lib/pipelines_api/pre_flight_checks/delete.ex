defmodule PipelinesAPI.PreFlightChecks.Delete do
  @moduledoc """
  Plug which removes pre-flight checks configuration for the organization,
  or for a single project when project_id is given.
  """

  require Logger

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.PreFlightChecksClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Util.ToTuple
  alias PipelinesAPI.Util.VerifyData, as: VD

  import PipelinesAPI.PreFlightChecks.Common,
    only: [has_pre_flight_checks_enabled: 2, audit_delete: 1]

  import PipelinesAPI.PreFlightChecks.Authorize, only: [authorize_manage: 2]

  @enabled_fields ~w(project_id)

  plug(:verify_params)
  plug(:has_pre_flight_checks_enabled)
  plug(:authorize_manage)
  plug(:delete_pre_flight_checks)

  def delete_pre_flight_checks(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["pfc_delete"], fn ->
      case audit_delete(conn) do
        {:ok, _audit} ->
          conn.params
          |> PreFlightChecksClient.destroy(conn)
          |> RespCommon.respond(conn)

        {:error, reason} ->
          Metrics.increment("PipelinesAPI.router", ["pfc_delete_audit_failed"])
          Logger.error("Failed to audit pre-flight checks delete request: #{inspect(reason)}")
          RespCommon.respond(ToTuple.internal_error("Internal error"), conn)
      end
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
