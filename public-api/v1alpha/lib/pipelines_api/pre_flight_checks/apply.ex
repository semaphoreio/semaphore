defmodule PipelinesAPI.PreFlightChecks.Apply do
  @moduledoc """
  Plug which creates or updates pre-flight checks configuration for the
  organization, or for a single project when project_id is given.
  """

  require Logger

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.PreFlightChecksClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Util.ToTuple
  alias PipelinesAPI.Util.VerifyData, as: VD

  import PipelinesAPI.PreFlightChecks.Common,
    only: [
      has_pre_flight_checks_enabled: 2,
      audit_apply: 1,
      is_non_empty_list_of_strings: 1,
      is_list_of_strings: 1,
      is_agent: 1
    ]

  import PipelinesAPI.PreFlightChecks.Authorize, only: [authorize_manage: 2]

  @enabled_fields ~w(project_id commands secrets agent)

  plug(:verify_params)
  plug(:has_pre_flight_checks_enabled)
  plug(:authorize_manage)
  plug(:apply_pre_flight_checks)

  def apply_pre_flight_checks(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["pfc_apply"], fn ->
      case audit_apply(conn) do
        {:ok, _audit} ->
          conn.params
          |> PreFlightChecksClient.apply(conn)
          |> RespCommon.respond(conn)

        {:error, reason} ->
          Metrics.increment("PipelinesAPI.router", ["pfc_apply_audit_failed"])
          Logger.error("Failed to audit pre-flight checks apply request: #{inspect(reason)}")
          RespCommon.respond(ToTuple.internal_error("Internal error"), conn)
      end
    end)
  end

  def verify_params(conn, _otps) do
    VD.verify(
      VD.is_valid_uuid?(conn.params["project_id"]),
      "project_id must be a valid UUID"
    )
    |> VD.verify(
      is_non_empty_list_of_strings(conn.params["commands"]),
      "commands must be a non-empty list of strings"
    )
    |> VD.verify(
      is_list_of_strings(conn.params["secrets"]),
      "secrets must be a list of secret names"
    )
    |> VD.verify(
      is_agent(conn.params["agent"]),
      "agent must be an object with a machine_type and an optional os_image"
    )
    |> VD.finalize_verification(conn, @enabled_fields)
  end
end
