defmodule PipelinesAPI.RoleBindings.Delete do
  @moduledoc """
  Plug deletes a deployment target.
  """

  use Plug.Builder
  require Logger

  alias PipelinesAPI.Util.Metrics
  # alias PipelinesAPI.RBACClient
  alias PipelinesAPI.Pipelines.Common

  # import PipelinesAPI.Deployments.Authorize, only: [authorize_manage_project: 2]

  # alias PipelinesAPI.Util.VerifyData, as: VD

  # @enabled_fields ~w(unique_token id target_id)

  # plug(:verify_params)
  # plug(:authorize_manage_project)
  plug(:delete)

  def delete(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["dt_delete"], fn ->
      Logger.info("INSIDE")
      Logger.info("#{inspect(conn.query_params)}")
      Common.respond({:ok, %{filed_name: "VALUE"}}, conn)
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
