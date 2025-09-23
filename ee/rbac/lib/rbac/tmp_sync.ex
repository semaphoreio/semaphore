defmodule Rbac.TempSync do
  @moduledoc """
    Temporary module for syncing changes in old role management system
    and new rbac system
  """
  require Logger
  import Ecto.Query
  import Rbac.RoleManagement, only: [assign_role: 3, user_part_of_org?: 2]

  def assign_org_member_role(user_id, org_id) do
    Logger.info("[Rbac Sync] Assign memeber role: user:#{user_id}, org:#{org_id}")
    {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: org_id)

    role_id =
      Rbac.Repo.RbacRole
      |> where([r], r.org_id == ^org_id and r.name == ^"Member")
      |> select([r], r.id)
      |> Rbac.Repo.one()

    case assign_role(rbi, role_id, :manually_assigned) do
      {:error, error_message} ->
        Logger.error("[Rbac Sync] #{error_message}")

        :error

      {:ok, nil} ->
        Watchman.increment("rbac_member_role_assigned")
        Logger.info("[Rbac Sync] Member role assigned")
        :ok
    end
  end

  def assign_org_owner_role(org_id, user_id \\ nil) do
    all_org_roles =
      case Rbac.Repo.RbacRole.list_roles(org_id) do
        [] -> Rbac.Repo.RbacRole.list_roles(Rbac.Utils.Common.nil_uuid())
        roles -> roles
      end

    owner_role_id =
      Enum.filter(all_org_roles, fn org_role -> org_role.name == "Owner" end)
      |> List.first()
      |> Map.fetch!(:id)

    owner_id =
      case user_id do
        nil ->
          get_org_creator_id(org_id)

        user_id ->
          user_id
      end

    with {:ok, _} <- Ecto.UUID.cast(owner_id) do
      Logger.info("Id of the owner: #{owner_id}")

      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: owner_id, org_id: org_id)

      case assign_role(rbi, owner_role_id, :manually_assigned) do
        {:error, error_message} ->
          Logger.error("[Rbac Sync] Could not assign owner role. #{error_message}")
          :error

        {:ok, nil} ->
          Watchman.increment("rbac_creator_role_assigned")
          :ok
      end
    end
  end

  def sync_new_user_with_members_table(user_id) do
    member_in_orgs =
      Rbac.FrontRepo.Member
      |> join(:inner, [m], rha in Rbac.FrontRepo.RepoHostAccount,
        on: m.github_uid == rha.github_uid
      )
      |> where([_, rha], rha.user_id == ^user_id)
      |> select([m], m.organization_id)
      |> Rbac.FrontRepo.all()

    Enum.each(member_in_orgs, fn org_id ->
      unless user_part_of_org?(user_id, org_id), do: assign_org_member_role(user_id, org_id)
    end)
  end

  def get_org_creator_id(org_id, no_of_retries \\ 0) do
    case Rbac.FrontRepo.Organization
         |> where([org], org.id == ^org_id)
         |> select([org], org.creator_id)
         |> Rbac.FrontRepo.one() do
      nil ->
        if no_of_retries == 0 do
          Logger.warning(
            "[Rbac Sync] Organization does not exist, trying to assign org owner again in 0.5 seconds."
          )

          :timer.sleep(500)
          get_org_creator_id(org_id, 1)
        else
          Logger.error(
            "[Rbac Sync] Cant create organization owner because organization is not in the front database"
          )

          :error
        end

      owner_id ->
        owner_id
    end
  end
end
