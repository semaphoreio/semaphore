defmodule PipelinesAPI.Deployments.List do
  @moduledoc """
  Plug lists all the deployment targets for a project, or it filters only one deployment
  target by its name.
  """

  use Plug.Builder

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.DeploymentsClient
  alias PipelinesAPI.Pipelines.Common

  import PipelinesAPI.Deployments.Authorize, only: [authorize_view_project: 2]

  import PipelinesAPI.Deployments.Common,
    only: [get_project_id_from_params: 2, has_deployment_targets_enabled: 2]

  alias PipelinesAPI.Util.VerifyData, as: VD

  @enabled_fields ~w(project_id target_name)

  plug(:verify_params)
  plug(:has_deployment_targets_enabled)
  plug(:get_project_id_from_params)
  plug(:authorize_view_project)
  plug(:list)

  def list(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["dt_list"], fn -> do_list(conn, conn.params) end)
  end

  def do_list(conn, %{"target_name" => _target_name}) do
    case DeploymentsClient.describe(conn.params) do
      {:ok, target} -> Common.respond({:ok, [target]}, conn)
      {:error, {:not_found, _}} -> Common.respond({:ok, []}, conn)
      error -> Common.respond(error, conn)
    end
  end

  def do_list(conn, _params) do
    conn.params
    |> DeploymentsClient.list()
    |> Common.respond(conn)
  end

  def verify_params(conn, _otps) do
    VD.verify(
      VD.is_string_length?(conn.params["target_name"], 1, 255),
      "target_name must be string with length between 1 and 255"
    )
    |> VD.verify(
      VD.is_valid_uuid?(conn.params["project_id"]),
      "project id must be a valid UUID"
    )
    |> VD.finalize_verification(conn, @enabled_fields)
  end
end
