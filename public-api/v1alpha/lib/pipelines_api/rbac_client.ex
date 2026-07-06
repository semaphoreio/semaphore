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
    LogTee.debug(params, "RBACClient.retract_role")

    Metrics.benchmark("PipelinesAPI.RBAC_client", ["retract_role"], fn ->
      params
      |> RequestFormatter.form_retract_role_request()
      |> GrpcClient.retract_role()
      |> ResponseFormatter.process_retract_role_response()
    end)
  end

  def list_org_members(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_org_members"], fn ->
      params
      |> RequestFormatter.form_list_org_members_request()
      |> GrpcClient.list_org_members()
      |> ResponseFormatter.process_list_members_response()
    end)
  end

  def list_org_roles(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_org_roles"], fn ->
      params
      |> RequestFormatter.form_list_org_roles_request()
      |> GrpcClient.list_roles()
      |> ResponseFormatter.process_list_roles_response("")
    end)
  end

  def describe_role(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["describe_role"], fn ->
      params
      |> RequestFormatter.form_describe_role_request()
      |> GrpcClient.describe_role()
      |> ResponseFormatter.process_describe_role_response()
    end)
  end

  def modify_role(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["modify_role"], fn ->
      params
      |> RequestFormatter.form_modify_role_request()
      |> GrpcClient.modify_role()
      |> ResponseFormatter.process_modify_role_response()
    end)
  end

  def destroy_role(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["destroy_role"], fn ->
      params
      |> RequestFormatter.form_destroy_role_request()
      |> GrpcClient.destroy_role()
      |> ResponseFormatter.process_destroy_role_response()
    end)
  end

  def assign_role(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["assign_role"], fn ->
      params
      |> RequestFormatter.form_assign_role_request()
      |> GrpcClient.assign_role()
      |> ResponseFormatter.process_assign_role_response()
    end)
  end

  def retract_project_role(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["retract_project_role"], fn ->
      params
      |> RequestFormatter.form_retract_project_role_request()
      |> GrpcClient.retract_role()
      |> ResponseFormatter.process_retract_role_response()
    end)
  end

  def list_existing_permissions(params) do
    Metrics.benchmark("PipelinesAPI.RBAC_client", ["list_existing_permissions"], fn ->
      params
      |> RequestFormatter.form_list_existing_permissions_request()
      |> GrpcClient.list_existing_permissions()
      |> ResponseFormatter.process_list_existing_permissions_response()
    end)
  end
end
