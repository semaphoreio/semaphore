defmodule InternalClients.RBAC do
  @moduledoc """
    Module is used for communication with RBAC service over gRPC.
  """

  alias InternalClients.RBACClient.{GrpcClient, RequestFormatter, ResponseFormatter}
  alias PublicAPI.Util.Metrics

  def list_project_members(params) do
    LogTee.debug(params, "RBACClient.list_project_members")

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_members"], fn ->
      params
      |> RequestFormatter.form_list_project_members_request()
      |> GrpcClient.list_project_members()
      |> ResponseFormatter.process_list_project_members_response()
    end)
  end

  def list_project_scope_roles(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_roles"], fn ->
      params
      |> RequestFormatter.form_list_roles_request()
      |> GrpcClient.list_roles()
      |> ResponseFormatter.process_list_roles_response(:SCOPE_PROJECT)
    end)
  end
end
