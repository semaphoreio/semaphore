defmodule FrontWeb.GroupsController do
  use FrontWeb, :controller
  require Logger

  alias Front.Async
  alias FrontWeb.Plugs.{FetchPermissions, PageAccess}
  alias Front.RBAC.{Groups, Members}

  @modify_endpoints ~w(create_group modify_group destroy_group)a

  plug(FetchPermissions, scope: "org")
  plug(PageAccess, permissions: "organization.people.view")
  plug(PageAccess, [permissions: "organization.people.manage"] when action in @modify_endpoints)

  plug(FrontWeb.Plugs.CacheControl, :no_cache)

  def fetch_group(conn, params) do
    org_id = conn.assigns.organization_id
    group_id = params["group_id"]

    case Groups.fetch_groups(org_id, group_id) do
      {:ok, groups} ->
        conn |> json(groups)

      {:error, err_msg} ->
        Logger.error(
          "[Groups Controller] Error while fetching groups. Org_id #{inspect(org_id)} group_id #{inspect(group_id)} error: #{inspect(err_msg)}"
        )

        conn |> send_resp(500, "Error while fetching groups") |> halt()
    end
  end

  def modify_group(conn, params) do
    org_id = conn.assigns.organization_id
    requester_id = conn.assigns.user_id
    name = params["name"]
    group_id = params["group_id"]
    description = params["description"]
    members_to_add = params["members_to_add"] || []
    members_to_remove = params["members_to_remove"] || []

    case Groups.modify_group(
           group_id,
           name,
           description,
           members_to_add,
           members_to_remove,
           org_id,
           requester_id
         ) do
      {:ok, _} ->
        conn
        |> put_flash(
          :notice,
          "Group successfully modified. It might take up to a minute for changes to apply."
        )
        |> redirect(to: people_path(conn, :organization))

      {:error, %{status: _, message: message}} ->
        Logger.error(
          "Error while modifying a group: #{inspect(message)}." <>
            "Org #{inspect(org_id)} name #{inspect(name)} description #{inspect(description)} requestor #{inspect(requester_id)}"
        )

        conn
        |> put_flash(:alert, URI.decode(message))
        |> redirect(to: people_path(conn, :organization))
    end
  end

  def create_group(conn, params) do
    org_id = conn.assigns.organization_id
    requester_id = conn.assigns.user_id
    name = params["name"]
    description = params["description"]
    member_ids = params["member_ids"] || []

    case Groups.create_group(name, description, member_ids, org_id, requester_id) do
      {:ok, _} ->
        conn
        |> put_flash(
          :notice,
          "Group successfully created. It might take up to a minute for changes to apply."
        )
        |> redirect(to: people_path(conn, :organization))

      {:error, err_msg} ->
        Logger.error(
          "Error while creating a group: #{inspect(err_msg)}." <>
            "Org #{inspect(org_id)} name #{inspect(name)} description #{inspect(description)} requestor #{inspect(requester_id)}"
        )

        conn
        |> put_flash(
          :alert,
          "An error occurred while creating a group. Please contact our support team."
        )
        |> redirect(to: people_path(conn, :organization))
    end
  end

  @max_people_per_org 2000
  @return_non_members 10
  def fetch_group_non_members(conn, params = %{"group_id" => group_id}) do
    org_id = conn.assigns.organization_id
    username = params["name_contains"] || ""

    fetch_org_members =
      Async.run(fn ->
        Members.list_org_members(org_id,
          username: username,
          page_size: @max_people_per_org
        )
      end)

    fetch_org_service_accounts =
      Async.run(fn ->
        Members.list_org_members(org_id,
          username: username,
          page_size: @max_people_per_org,
          member_type: "service_account"
        )
      end)

    if group_id != "nil" do
      fetch_group_members = Async.run(fn -> Groups.fetch_group_members(org_id, group_id) end)

      {:ok, {:ok, group_members}} = Async.await(fetch_group_members)
      {:ok, {:ok, {org_members, _total_pages}}} = Async.await(fetch_org_members)

      {:ok, {:ok, {service_account_members, _total_pages}}} =
        Async.await(fetch_org_service_accounts)

      non_members =
        (org_members ++ service_account_members)
        |> Enum.filter(fn member -> member.id not in Enum.map(group_members, & &1.id) end)

      conn |> json(non_members |> Enum.take(@return_non_members))
    else
      {:ok, {:ok, {org_members, _total_pages}}} = Async.await(fetch_org_members)

      {:ok, {:ok, {service_account_members, _total_pages}}} =
        Async.await(fetch_org_service_accounts)

      conn |> json((org_members ++ service_account_members) |> Enum.take(@return_non_members))
    end
  end

  def fetch_group_members(conn, %{"group_id" => group_id}) do
    org_id = conn.assigns.organization_id

    {:ok, group_members} = Groups.fetch_group_members(org_id, group_id)

    conn |> json(group_members)
  end

  def destroy_group(conn, params) do
    org_id = conn.assigns.organization_id
    requester_id = conn.assigns.user_id
    group_id = params["group_id"]

    case Groups.destroy_group(group_id, requester_id) do
      {:ok, _} ->
        conn
        |> put_flash(
          :notice,
          "Request for deleting the group has been sent. It might take up to a minute for the request to be processed."
        )
        |> redirect(to: people_path(conn, :organization))

      {:error, err_msg} ->
        Logger.error(
          "Error while deleting a group: #{inspect(err_msg)}." <>
            "Org #{inspect(org_id)} group_id #{inspect(group_id)} requestor #{inspect(requester_id)}"
        )

        conn
        |> put_flash(
          :alert,
          "An error occurred: #{err_msg.message}. Please contact our support team."
        )
        |> redirect(to: people_path(conn, :organization))
    end
  end
end
