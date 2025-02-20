defmodule Guard.Rbac.TempSync do
  @moduledoc """
    Temporary module for syncing changes in old role management system
    and new rbac system
  """
  require Logger
  import Ecto.Query

  def sync_new_user_with_members_table(user_id) do
    member_in_orgs =
      Guard.FrontRepo.Member
      |> join(:inner, [m], rha in Guard.FrontRepo.RepoHostAccount,
        on: m.github_uid == rha.github_uid
      )
      |> where([_, rha], rha.user_id == ^user_id)
      |> select([m], m.organization_id)
      |> Guard.FrontRepo.all()

    Enum.each(member_in_orgs, fn org_id ->
      unless Guard.Api.Rbac.user_part_of_org?(user_id, org_id),
        do: Guard.Api.Rbac.assign_org_role_by_name(user_id, org_id, "Member")
    end)
  end
end
