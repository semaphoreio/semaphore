defmodule Front.RBAC.Groups do
  require Logger

  alias InternalApi.Groups

  @default_size 10
  def fetch_groups(org_id, group_id \\ "", page_no \\ 1, page_size \\ @default_size) do
    req =
      Groups.ListGroupsRequest.new(
        org_id: org_id,
        group_id: group_id,
        page:
          Groups.ListGroupsRequest.Page.new(
            page_no: page_no,
            page_size: page_size
          )
      )

    Front.RBAC.GroupsClient.channel()
    |> Groups.Groups.Stub.list_groups(req)
    |> case do
      {:ok, resp} ->
        if group_id != "" do
          {:ok, hd(resp.groups) |> inject_user_data()}
        else
          {:ok, resp.groups |> Enum.map(&inject_user_data/1)}
        end

      e ->
        e
    end
  end

  def create_group(name, description, member_ids, org_id, creator_id) do
    req =
      Groups.CreateGroupRequest.new(
        org_id: org_id,
        requester_id: creator_id,
        group:
          InternalApi.Groups.Group.new(
            name: name,
            description: description,
            member_ids: member_ids
          )
      )

    Front.RBAC.GroupsClient.channel()
    |> Groups.Groups.Stub.create_group(req)
    |> case do
      {:ok, _} -> {:ok, nil}
      e -> e
    end
  end

  def destroy_group(group_id, requester_id) do
    req =
      Groups.DestroyGroupRequest.new(
        group_id: group_id,
        requester_id: requester_id
      )

    Front.RBAC.GroupsClient.channel()
    |> Groups.Groups.Stub.destroy_group(req)
    |> case do
      {:ok, _} -> {:ok, nil}
      e -> e
    end
  end

  def modify_group(
        group_id,
        name,
        description,
        members_to_add,
        members_to_remove,
        org_id,
        creator_id
      ) do
    req =
      Groups.ModifyGroupRequest.new(
        org_id: org_id,
        requester_id: creator_id,
        members_to_add: members_to_add,
        members_to_remove: members_to_remove,
        group:
          InternalApi.Groups.Group.new(
            id: group_id,
            name: name,
            description: description
          )
      )

    Front.RBAC.GroupsClient.channel()
    |> Groups.Groups.Stub.modify_group(req)
    |> case do
      {:ok, _} -> {:ok, nil}
      e -> e
    end
  end

  def fetch_group_members(org_id, group_id) do
    req =
      Groups.ListGroupsRequest.new(
        org_id: org_id,
        group_id: group_id,
        page: Groups.ListGroupsRequest.Page.new()
      )

    Front.RBAC.GroupsClient.channel()
    |> Groups.Groups.Stub.list_groups(req)
    |> case do
      {:ok, resp} -> {:ok, List.first(resp.groups) |> inject_user_data() |> Map.get(:members)}
      e -> e
    end
  end

  defp inject_user_data(group) when is_nil(group), do: []

  defp inject_user_data(group) do
    members =
      Front.Models.User.find_many(group.member_ids)
      |> Enum.map(
        &%{
          id: &1.id,
          name: &1.name,
          avatar: &1.avatar_url
        }
      )

    member_user_ids = members |> Enum.map(& &1.id)
    non_member_ids = group.member_ids -- member_user_ids

    service_accounts =
      Front.ServiceAccount.describe_many(non_member_ids)
      |> case do
        {:ok, service_accounts} ->
          service_accounts

        _ ->
          []
      end
      |> Enum.map(
        &%{
          id: &1.id,
          name: &1.name,
          avatar: ""
        }
      )

    group |> Map.put(:members, members ++ service_accounts)
  end
end
