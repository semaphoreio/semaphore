defmodule Rbac.Repo.Queries do
  import Ecto.Query

  alias Rbac.Repo.{
    Group,
    RbacUser,
    UserGroupBinding,
    RbacRole,
    OrgRoleToProjRoleMapping,
    RoleInheritance
  }

  @doc ~S"""
    Pairs user to all of the rbac subjects it belongs to. This includes a subject
    for each group the user is a part of, plus a default subject for that user.

    Example:
      User with id 1 is part of groups 7 and 9.

      This function returns a query which would upon its execution return:
      [%{user_id: 1, subject_id: 1}, %{user_id: 1, subject_id: 7}, %{user_id: 1, subject_id: 9}]
  """
  def user_to_subject_bindings_query(id) do
    if group?(id) do
      expand_group_to_its_members(id)
    else
      user_to_group_bindings = user_to_group_bindings_query(id)

      default_user_subject_binding =
        RbacUser
        |> select([u], %{user_id: u.id, subject_id: u.id})
        |> add_where_clause_for_specific_user(id)

      default_user_subject_binding |> union_all(^user_to_group_bindings)
    end
  end

  defp user_to_group_bindings_query(user_id) do
    RbacUser
    |> join(:inner, [u], ugb in UserGroupBinding, on: u.id == ugb.user_id)
    |> select([u, ugb], %{user_id: u.id, subject_id: ugb.group_id})
    |> add_where_clause_for_specific_user(user_id)
  end

  def expand_group_to_its_members(group_id) do
    user_members_to_group_bindings =
      Group
      |> where([g], g.id == ^group_id)
      |> join(:inner, [g], ugb in UserGroupBinding, on: g.id == ugb.group_id)
      |> select([_, ugb], %{user_id: ugb.user_id, subject_id: ugb.group_id})

    user_member_bindings_to_themselves =
      Group
      |> where([g], g.id == ^group_id)
      |> join(:inner, [g], ugb in UserGroupBinding, on: g.id == ugb.group_id)
      |> select([_, ugb], %{user_id: ugb.user_id, subject_id: ugb.user_id})

    user_members_to_group_bindings |> union_all(^user_member_bindings_to_themselves)
  end

  @doc ~S"""
    This function takes each role, and pairs it with all of the roles it inherits from and maps to.
    It uses recursive CTEs to achieve that.

    Example:
      Org level role with id 1 maps to project level role 3. It also inherits from role 4, which in
      turn inherits from role 7. None of these two roles map to any project level roles.

      This function would return (some of the fields are ommited):
      [
        %{inheriting_role_id: 1, inherited_role_id: 1, mapped_proj_rol_id: 3},
        %{inheriting_role_id: 1, inherited_role_id: 4, mapped_proj_rol_id: null},
        %{inheriting_role_id: 1, inherited_role_id: 7, mapped_proj_rol_id: null},
        %{inheriting_role_id: 4, inherited_role_id: 4, mapped_proj_rol_id: null},
        %{inheriting_role_id: 4, inherited_role_id: 7, mapped_proj_rol_id: null},
        %{inheriting_role_id: 7, inherited_role_id: 7, mapped_proj_rol_id: null}
      ]

      Based on this, we would be able to deduce that anyone with role 1 has all the permissions
      given by the roles 1,4,7 and 3
  """
  def role_inheritance_and_mappings_query do
    role_inheritance_recursive = role_inheritance_query_recursive_step()

    inheritance_query =
      role_inheritance_query_initial_step()
      |> union_all(^role_inheritance_recursive)

    recursive_ctes(inheritance_query, true)
    |> with_cte("role_inheritance_tree", as: ^inheritance_query)
  end

  # This query sets up the initial state of recursive CTE query. I does not take into the account
  # role inheritance, and assumes each role inherits only itslef. It also checks if that role maps
  # to any project level role, and if so , to which one (this will be true only in case of some
  # organization level roles).
  defp role_inheritance_query_initial_step do
    RbacRole
    |> join(:left, [r], orm in OrgRoleToProjRoleMapping, on: r.id == orm.org_role_id)
    |> select([r, orm], %{
      inheriting_role_id: r.id,
      inherited_role_id: r.id,
      mapped_proj_role_id: orm.proj_role_id,
      scope_id: r.scope_id,
      depth: 0
    })
  end

  # When the initial set of roles is created based on the query above, now we can use that set (refered to here
  # as the `role_inheritance_tree` table) to join all of those roles with roles they are inheriting based on
  # `role_inheritance` table. This is the recursive part of the recusrsive CTE
  defp role_inheritance_query_recursive_step do
    RoleInheritance
    |> join(:inner, [ri], rit in "role_inheritance_tree",
      on: ri.inheriting_role_id == rit.inherited_role_id
    )
    |> join(:left, [ri], orm in OrgRoleToProjRoleMapping,
      on: ri.inherited_role_id == orm.org_role_id
    )
    |> select([ri, rit, orm], %{
      inheriting_role_id: rit.inheriting_role_id,
      inherited_role_id: ri.inherited_role_id,
      mapped_proj_role_id: orm.proj_role_id,
      scope_id: rit.scope_id,
      depth: rit.depth + 1
    })
  end

  ###
  ### Helper functions
  ###

  defp group?(nil), do: false
  defp group?(id), do: {:error, :not_found} != Rbac.Store.Group.fetch_group(id)

  defp add_where_clause_for_specific_user(query, nil), do: query

  defp add_where_clause_for_specific_user(query, user_id),
    do: query |> where([u], u.id == ^user_id)
end
