defmodule PipelinesAPI.GroupsClient.RequestFormatter do
  @moduledoc false
  alias Plug.Conn
  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.Groups

  def form_list_request(_params, conn) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    Groups.ListGroupsRequest.new(org_id: org_id)
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_create_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    name = Map.get(params, "name", "")
    description = Map.get(params, "description", "")
    member_ids = Map.get(params, "member_ids", [])
    member_ids = if is_list(member_ids), do: Enum.filter(member_ids, &is_binary/1), else: []

    if name == "" do
      ToTuple.user_error("Name must be provided")
    else
      Groups.CreateGroupRequest.new(
        group:
          Groups.Group.new(
            name: name,
            description: description,
            member_ids: member_ids
          ),
        org_id: org_id,
        requester_id: requester_id
      )
      |> ToTuple.ok()
    end
  catch
    error -> error
  end

  def form_create_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_modify_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    group_id = Map.get(params, "id", "")

    to_add = Map.get(params, "members_to_add", [])
    to_add = if is_list(to_add), do: Enum.filter(to_add, &is_binary/1), else: []
    to_remove = Map.get(params, "members_to_remove", [])
    to_remove = if is_list(to_remove), do: Enum.filter(to_remove, &is_binary/1), else: []

    Groups.ModifyGroupRequest.new(
      group:
        Groups.Group.new(
          id: group_id,
          name: Map.get(params, "name", ""),
          description: Map.get(params, "description", "")
        ),
      org_id: org_id,
      requester_id: requester_id,
      members_to_add: to_add,
      members_to_remove: to_remove
    )
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_modify_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_destroy_request(params, conn) when is_map(params) do
    requester_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")

    Groups.DestroyGroupRequest.new(
      group_id: Map.get(params, "id", ""),
      requester_id: requester_id
    )
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_destroy_request(_, _), do: ToTuple.internal_error("Internal error")
end
