defmodule Guard.Store.Invitations do
  require Logger

  alias Guard.FrontRepo
  alias Guard.Repo

  import Ecto.Query

  def list(org_id) do
    from(
      m in FrontRepo.Member,
      left_join: rha in FrontRepo.RepoHostAccount,
      on: m.github_uid == rha.github_uid and m.repo_host == rha.repo_host
    )
    |> where([m, rha], m.organization_id == ^org_id and is_nil(rha.id))
    |> select(
      [m, _],
      %{
        id: m.id,
        display_name: m.github_username,
        provider: m.repo_host,
        uid: m.github_uid,
        invited_at: m.created_at,
        email: m.invite_email
      }
    )
    |> FrontRepo.all()
    |> return_ok_tuple()
  end

  def create(invitees, org_id) do
    invitees
    |> map_member_params(org_id)
    |> Enum.map(&upsert_member/1)
    |> Enum.filter(& &1)
    |> Enum.uniq_by(& &1.github_uid)
    |> return_ok_tuple()
  end

  defp map_member_params(invitees, org_id) when is_list(invitees),
    do: Enum.map(invitees, fn invitee -> map_member_params(invitee, org_id) end)

  defp map_member_params(invitee, org_id) do
    %{
      github_uid: invitee.provider.uid,
      github_username: invitee.provider.login,
      repo_host: map_repo_host(invitee.provider.type),
      organization_id: org_id,
      invite_email: invitee.email
    }
  end

  defp map_repo_host(type) do
    type
    |> Atom.to_string()
    |> String.downcase()
  end

  defp upsert_member(params) do
    %FrontRepo.Member{}
    |> FrontRepo.Member.changeset(params)
    |> FrontRepo.insert(
      on_conflict: {:replace, [:github_username, :invite_email, :updated_at]},
      conflict_target: [:github_uid, :repo_host, :organization_id]
    )
    |> case do
      {:ok, member} ->
        member

      {:error, %Ecto.Changeset{errors: errors}} ->
        Logger.error("Error with inserting member: #{inspect(params)} error: #{inspect(errors)}")
        nil
    end
  end

  def collaborators(org_id, project_id \\ "") do
    {:ok, members} = member_collaborators(org_id, project_id)
    {:ok, invitees} = list(org_id)
    members = map_members_to_providers(members)
    invitees = map_invitees_to_providers(invitees)

    providers = Enum.concat(members, invitees)

    all_collabortors(org_id, project_id)
    |> Enum.reject(fn c ->
      Enum.member?(providers, %{uid: c.uid, provider: c.provider})
    end)
    |> return_ok_tuple()
  end

  defp member_collaborators(org_id, ""),
    do: Guard.Store.Members.organization(org_id)

  defp member_collaborators(org_id, project_id),
    do: Guard.Store.Members.project(org_id, project_id)

  defp map_members_to_providers(members) do
    members
    |> Enum.map(fn member ->
      Enum.map(member.providers, fn provider ->
        %{uid: provider.uid, provider: provider.provider}
      end)
    end)
    |> List.flatten()
  end

  defp map_invitees_to_providers(invitees),
    do: Enum.map(invitees, fn invitee -> Map.take(invitee, [:uid, :provider]) end)

  defp all_collabortors(org_id, project_id) do
    from(
      c in Repo.Collaborator,
      left_join: p in Repo.Project,
      on: c.project_id == p.project_id
    )
    |> filter_by_project(project_id)
    |> where([_, p], p.org_id == ^org_id)
    |> distinct([c, _], c.github_uid)
    |> select(
      [c, p],
      %{
        uid: c.github_uid,
        login: c.github_username,
        provider: p.provider,
        display_name: c.github_username
      }
    )
    |> Repo.all()
  end

  defp filter_by_project(query, ""), do: query

  defp filter_by_project(query, project_id),
    do: query |> where([_, p], p.project_id == ^project_id)

  defp return_ok_tuple(value), do: {:ok, value}
end
