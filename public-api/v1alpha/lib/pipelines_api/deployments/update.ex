defmodule PipelinesAPI.Deployments.Update do
  @moduledoc """
  Plug updates a deployment target.
  """

  use Plug.Builder

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.DeploymentsClient
  alias PipelinesAPI.Pipelines.Common

  import PipelinesAPI.Deployments.Secrets, only: [inject_old_secrets: 2]

  import PipelinesAPI.Deployments.Common,
    only: [
      get_project_id_from_target: 2,
      has_deployment_targets_enabled: 2,
      remove_sensitive_params: 2,
      is_list_of_subject_rules: 1,
      is_list_of_object_rules: 1
    ]

  import PipelinesAPI.Secrets.Key, only: [get_key: 2]
  import PipelinesAPI.Deployments.Authorize, only: [authorize_manage_project: 2]

  alias PipelinesAPI.Util.VerifyData, as: VD

  @enabled_fields ~w(unique_token id target_id env_vars files project_id name description url subject_rules object_rules bookmark_parameter1 bookmark_parameter2 bookmark_parameter3)

  plug(:verify_params)
  plug(:remove_sensitive_params)
  plug(:has_deployment_targets_enabled)
  plug(:get_project_id_from_target)
  plug(:authorize_manage_project)
  plug(:get_key)
  plug(:inject_old_secrets)
  plug(:inject_target)
  plug(:update)

  def update(conn, _opts) do
    LogTee.debug(conn, "Deployments.Update received request")

    Metrics.benchmark("PipelinesAPI.router", ["dt_update"], fn ->
      conn.params
      |> DeploymentsClient.update(conn)
      |> Common.respond(conn)
    end)
  end

  def inject_target(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["dt_inject_target"], fn ->
      case DeploymentsClient.describe(conn.params) do
        {:ok, response} ->
          Map.put(conn, :params, Map.put(conn.params, "old_target", response))

        error ->
          error
      end
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
    |> VD.verify(
      VD.is_valid_uuid?(conn.params["project_id"]),
      "project id must be a valid UUID"
    )
    |> VD.verify(
      is_list_of_subject_rules(conn.params["subject_rules"]),
      "subject_rules must be a list of proper objects"
    )
    |> VD.verify(
      is_list_of_object_rules(conn.params["object_rules"]),
      "object_rules must be a list of proper objects"
    )
    |> VD.finalize_verification(conn, @enabled_fields)
  end
end
