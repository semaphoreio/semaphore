defmodule PipelinesAPI.RBACClient do
  @moduledoc """
    Module is used for communication with RBAC service over gRPC.
  """

  alias PipelinesAPI.RBACClient.{GrpcClient, RequestFormatter, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def list_user_permissions(params) do
    LogTee.debug(params, "RBACClient.list_user_permissions")

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_user_permissions"], fn ->
      params
      |> RequestFormatter.form_list_user_permissions()
      |> GrpcClient.list_user_permissions()
      |> ResponseFormatter.process_list_user_permissions()
    end)
  end

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
      |> ResponseFormatter.process_list_roles_response(
        InternalApi.RBAC.Scope.value(:SCOPE_PROJECT)
      )
    end)
  end

  def retract_role(params) do
    params
    |> RequestFormatter.form_list_roles_request()
    |> GrpcClient.list_roles()
    |> ResponseFormatter.process_list_roles_response(InternalApi.RBAC.Scope.value(:SCOPE_PROJECT))
  end
end
