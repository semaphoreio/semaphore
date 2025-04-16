defmodule Rbac.GrpcServers.GroupsServer do
  @moduledoc """
    Documentation for all of the endpoints can be found in the internal_api repo: https://github.com/renderedtext/internal_api/blob/master/groups.proto
  """
  use GRPC.Server, service: InternalApi.Groups.Groups.Service

  import Rbac.Utils.Grpc, only: [validate_uuid!: 1, authorize!: 3, grpc_error!: 1, grpc_error!: 2]

  require Logger
  alias InternalApi.Groups
  alias Rbac.Store.Group

  @default_page_size 10
  @manage_groups_permission "organization.people.manage"

  def create_group(
        %Groups.CreateGroupRequest{org_id: org_id, requester_id: requester_id, group: group},
        _stream
      ) do
    validate_uuid!([org_id, requester_id])
    authorize!(@manage_groups_permission, requester_id, org_id)
    validate_group_parameters!(group)
    check_if_members_are_in_org!(group.member_ids, org_id)

    case Group.create_group(group, org_id, requester_id) do
      {:ok, created_group} ->
        Rbac.TempSync.assign_org_member_role(created_group.id, org_id)

        Enum.each(group.member_ids, fn member_id ->
          Rbac.Repo.GroupManagementRequest.create_new_request(
            member_id,
            created_group.id,
            :add_user,
            requester_id
          )
        end)

        %Groups.CreateGroupResponse{group: construct_grpc_group(created_group)}

      {:error, err_msg} ->
        Watchman.increment("create_group.failure")
        grpc_error!(:internal, err_msg)
    end
  end

  def list_groups(
        %Groups.ListGroupsRequest{org_id: org_id, group_id: group_id, page: page},
        _stream
      ) do
    validate_uuid!(org_id)
    if group_id != "", do: validate_uuid!(group_id)

    page = page || %{page_no: 0, page_size: @default_page_size}

    groups =
      if group_id == "" do
        Group.fetch_all_org_groups(org_id, page.page_no, page.page_size)
      else
        case Group.fetch_group(group_id) do
          {:ok, group} -> [group]
          {:error, _} -> []
        end
      end

    %Groups.ListGroupsResponse{groups: groups |> Enum.map(&construct_grpc_group/1)}
  end

  def modify_group(%Groups.ModifyGroupRequest{} = req, _stream) do
    alias Rbac.Repo.GroupManagementRequest

    if req.group == nil,
      do: grpc_error!(:invalid_argument, "Required group information not provided")

    validate_uuid!([req.org_id, req.requester_id, req.group.id])
    authorize!(@manage_groups_permission, req.requester_id, req.org_id)
    check_if_members_are_in_org!(req.members_to_add, req.org_id)

    with {:ok, _} <- Group.fetch_group(req.group.id),
         {:ok, group} <-
           Group.modify_metadata(req.group.id, req.group.name, req.group.description) do
      GroupManagementRequest.create_new_request(
        req.members_to_remove,
        group.id,
        :remove_user,
        req.requester_id
      )

      GroupManagementRequest.create_new_request(
        req.members_to_add,
        group.id,
        :add_user,
        req.requester_id
      )

      %Groups.ModifyGroupResponse{group: construct_grpc_group(group)}
    else
      {:error, :not_found} ->
        grpc_error!(:invalid_argument, "The group you are trying to modify does not exist")

      {:error, _error_msg} ->
        Watchman.increment("modify_group.failure")
        grpc_error!(:internal)
    end
  end

  def destroy_group(
        %Groups.DestroyGroupRequest{group_id: group_id, requester_id: requester_id},
        _stream
      ) do
    alias Rbac.Repo.GroupManagementRequest

    validate_uuid!([requester_id, group_id])

    case Group.fetch_group(group_id) do
      {:ok, group} ->
        authorize!(@manage_groups_permission, requester_id, group.org_id)

        {:ok, _request} =
          GroupManagementRequest.create_new_request(nil, group_id, :destroy_group, requester_id)

        %Groups.DestroyGroupResponse{}

      {:error, :not_found} ->
        grpc_error!(:not_found, "The group you are trying to destroy does not exist")

      {:error, _error_msg} ->
        Watchman.increment("destroy_group.failure")
        grpc_error!(:internal, "Groups service, internal server error")
    end
  end

  ###
  ### Helper functions
  ###

  defp validate_group_parameters!(nil),
    do: grpc_error!(:invalid_argument, "No group information provided")

  defp validate_group_parameters!(group) do
    if group.name == "" or group.name == nil,
      do: grpc_error!(:invalid_argument, "Group name is required")

    if group.description == "" or group.description == nil,
      do: grpc_error!(:invalid_argument, "Group description is required")
  end

  defp check_if_members_are_in_org!(member_ids, org_id) do
    alias Rbac.RoleManagement

    if Enum.any?(member_ids, &(!RoleManagement.user_part_of_org?(&1, org_id))) do
      grpc_error!(
        :invalid_argument,
        "All of the members you want to add to the group have to already be part of the organization"
      )
    end
  end

  defp construct_grpc_group(group) do
    %InternalApi.Groups.Group{
      id: group.id,
      name: group.name,
      description: group.description,
      member_ids: Rbac.Repo.UserGroupBinding.fetch_group_members(group.id) |> Enum.map(& &1.id)
    }
  end
end
