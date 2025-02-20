# TODO deprecated, should be removed once we migrate invitations to Guard
defmodule Guard.Store.Members do
  require Logger

  alias Guard.FrontRepo

  import Ecto.Query

  @doc """
  Removes all members for a given user or with given member_id
  """
  def cleanup(org_id, user_id, member_id) do
    if is_binary(user_id) and user_id != "" do
      from(rha in FrontRepo.RepoHostAccount, where: rha.user_id == ^user_id)
      |> select([rha], [rha.github_uid, rha.repo_host])
      |> FrontRepo.all()
      |> Enum.each(fn [github_uid, repo_host] ->
        from(m in FrontRepo.Member,
          where:
            m.organization_id == ^org_id and m.github_uid == ^github_uid and
              m.repo_host == ^repo_host
        )
        |> FrontRepo.delete_all()
      end)
    end

    if is_binary(member_id) and member_id != "" do
      from(m in FrontRepo.Member, where: m.organization_id == ^org_id and m.id == ^member_id)
      |> FrontRepo.delete_all()
    end
  end

  def count_memberships(member, org_id) do
    sql = """
    SELECT COUNT(*) FROM members WHERE CONCAT(github_uid, '-', repo_host) IN (
      SELECT CONCAT(github_uid, '-', repo_host) FROM repo_host_accounts WHERE user_id = (
        SELECT user_id FROM repo_host_accounts WHERE github_uid = $1 AND repo_host = $2
      )
    ) AND organization_id = $3
    """

    {:ok, %{rows: [[count]]}} =
      FrontRepo.query(sql, [member.github_uid, member.repo_host, Ecto.UUID.dump!(org_id)])

    count
  end

  def extract_user_id(members) when is_list(members) do
    members
    |> Enum.map(fn member -> extract_user_id(member) end)
    |> Enum.filter(& &1)
  end

  def extract_user_id(member) do
    sql = """
    SELECT user_id FROM repo_host_accounts WHERE github_uid = $1 AND repo_host = $2
    """

    case FrontRepo.query(sql, [member.github_uid, member.repo_host]) do
      {:ok, %{rows: [[user_id]]}} -> user_id |> Ecto.UUID.cast!()
      _ -> nil
    end
  end

  def project(org_id, project_id, options \\ []) do
    defaults = [
      name_contains: ""
    ]

    options = defaults |> Keyword.merge(options)
    user_ids = get_project_access_from_rbac(org_id, project_id)

    {:ok, users} =
      organization(org_id,
        user_ids: user_ids,
        name_contains: Keyword.fetch!(options, :name_contains)
      )

    {:ok, users}
  end

  defp get_project_access_from_rbac(org_id, project_id) do
    Guard.Api.Rbac.list_members(org_id, project_id)
    |> Enum.map(fn member -> member.subject.subject_id end)
  end

  def organization(org_id, options \\ [])
  def organization(_, user_ids: []), do: [] |> return_ok_tuple()

  def organization(org_id, options) do
    defaults = [
      name_contains: "",
      user_ids: nil
    ]

    options = defaults |> Keyword.merge(options)

    subquery =
      from(
        m in FrontRepo.Member,
        inner_join: rha in FrontRepo.RepoHostAccount,
        on: m.github_uid == rha.github_uid and m.repo_host == rha.repo_host,
        inner_join: u in FrontRepo.User,
        on: rha.user_id == u.id
      )
      |> filter_by_user_ids(Keyword.fetch!(options, :user_ids))
      |> where([m, _, _], m.organization_id == ^org_id)
      |> select([_, _, u], u.id)

    from(
      u in FrontRepo.User,
      inner_join: rha in FrontRepo.RepoHostAccount,
      on: u.id == rha.user_id
    )
    |> where([u, _], u.id in subquery(subquery))
    |> group_by([u, _], u.id)
    |> order_by([u, _], u.name)
    |> select(
      [u, rha],
      %{
        email: u.email,
        user_id: u.id,
        display_name: u.name,
        providers:
          fragment(
            "jsonb_agg(jsonb_build_object('login', ?, 'uid', ?, 'provider', ?))",
            rha.login,
            rha.github_uid,
            rha.repo_host
          )
      }
    )
    |> filter_by_name(Keyword.fetch!(options, :name_contains))
    |> FrontRepo.all()
    |> map_providers_to_atoms()
    |> return_ok_tuple()
  end

  defp map_providers_to_atoms(members) when is_list(members),
    do: Enum.map(members, fn m -> map_providers_to_atoms(m) end)

  defp map_providers_to_atoms(member) do
    Map.merge(member, %{providers: keys_to_atoms(member.providers)})
  end

  defp keys_to_atoms(maps) when is_list(maps),
    do: Enum.map(maps, fn map -> keys_to_atoms(map) end)

  defp keys_to_atoms(map) do
    map |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
  end

  defp filter_by_user_ids(query, nil), do: query

  defp filter_by_user_ids(query, user_ids),
    do: query |> where([_, _, u], u.id in ^user_ids)

  defp filter_by_name(query, ""), do: query

  defp filter_by_name(query, name),
    do: query |> where([u, rha], ilike(u.name, ^"%#{name}%") or ilike(rha.login, ^"%#{name}%"))

  defp return_ok_tuple(value), do: {:ok, value}
end
