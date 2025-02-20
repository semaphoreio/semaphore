defmodule Rbac.ComputePermissions do
  # credo:disable-for-this-file
  @moduledoc """
    This module is used only for calculating a list of permissions given user has within the organization or
    the project, based on the roles they have assigned to them, and based on the groups they are members of.
  """
  require Logger
  import Ecto.Query

  alias Rbac.RoleBindingIdentification, as: RBI
  alias Rbac.Repo.Queries

  alias Rbac.Repo.{SubjectRoleBinding, RolePermissionBinding, Permission}

  @doc """
  Function that constructs and executes query for calculating user permissions

  Parameters: There are three optional parameters for filtering which permissions will be calculated. If
  none are present, then entire cache is recalculated, otherwise just the cahce for a specific user, org, project
  (or combination of these) is returned.

    - user_id: "string"
    - org_id: "string"
    - project_id: "string"

  Returns:
  - {:ok, data} or {:error, error}
    Where data is list of maps. Each map in that list containes four values

    :user_id - Id of the user to whom permissions belong
    :org_id - Id of the organization for which those permissions apply (might be '*' if the user
    has these permissions for every organization in the system. This will be true only for
    selected semaphore employees)
    :project_id - Id of the project for which those permission apply (might be '*' if permissions
    apply to entire org or all projects within that org)
    :permission_names - String that lists all of the permissions separated by comma (,)
  """
  @spec compute_permissions(RBI.t()) ::
          {:ok,
           list(%{
             user_id: String.t(),
             org_id: String.t(),
             project_id: String.t(),
             permission_names: String.t()
           })}
          | {:error, any()}
  def compute_permissions(rbi) do
    Logger.info("Computing permissions for #{inspect(rbi)}")

    metrics_name =
      if rbi.project_id == nil || rbi.project_id == :is_nil do
        "compute_permissions.duration.all_permissions"
      else
        "compute_permissions.duration.one_project"
      end

    Watchman.benchmark(metrics_name, fn ->
      with :ok <- validate_role_binding_identification(rbi) do
        query = gen_complete_query(rbi)

        try do
          value = Rbac.Repo.all(query, timeout: 60_000)
          {:ok, value}
        rescue
          Ecto.QueryError -> {:error, "Query validation failed"}
        end
      else
        _ ->
          error_msg =
            "User, org and project ids are empty. One (or more) of those values must be present in order " <>
              "to narrow down permission computation. For recalculating all permisions in system use " <>
              "'compute_all_permissions' function."

          Logger.warning(error_msg)
          {:error, error_msg}
      end
    end)
  end

  @doc ~S"""
    Should be used only when something goes wrong to recalculate all the permissions for all
    users within every org or project. Query will take few minutes to complete.
  """
  @spec compute_all_permissions(integer()) :: Enum.t()
  def compute_all_permissions(batch_size \\ 20_000) do
    query = gen_complete_query(%RBI{})
    Rbac.Repo.stream(query, max_rows: batch_size, timeout: 360_000)
  end

  defp gen_complete_query(%{user_id: user_id, org_id: org_id, project_id: project_id}) do
    user_to_subject_bindings = Queries.user_to_subject_bindings_query(user_id)
    role_inheritance_tree = Queries.role_inheritance_and_mappings_query()

    user_to_permission_bindings =
      user_permission_bindings_query(
        user_to_subject_bindings,
        role_inheritance_tree,
        org_id,
        project_id
      )

    aggregate_permissions(user_to_permission_bindings)
  end

  # When we know which user belongs to which subject, and which role inherits/maps_to which
  # other role, we can user `subject_role_bindings` table and `role_permissions` table to get
  # all of the permissions each user has within any org or project
  defp user_permission_bindings_query(
         user_to_subject_bindings,
         role_inheritance_tree,
         org_id,
         project_id
       ) do
    SubjectRoleBinding
    |> join(:inner, [srb], u in subquery(user_to_subject_bindings),
      on: u.subject_id == srb.subject_id
    )
    |> join(:inner, [srb], rit in subquery(role_inheritance_tree),
      on: rit.inheriting_role_id == srb.role_id
    )
    |> join(:inner, [_, _, rit], pb in RolePermissionBinding,
      on: rit.inherited_role_id == pb.rbac_role_id or rit.mapped_proj_role_id == pb.rbac_role_id
    )
    |> join(:inner, [_, _, _, pb], p in Permission, on: p.id == pb.permission_id)
    |> group_by([srb, u], [u.user_id, srb.org_id, srb.project_id])
    |> select([srb, u, _, _, p], %{
      user_id: u.user_id,
      org_id: srb.org_id,
      project_id: fragment("COALESCE(?::text, '*')", srb.project_id),
      permission_names: fragment("string_agg(DISTINCT (?::text), ',')", p.name)
    })
    |> add_where_clause_for_specific_org(org_id)
    |> add_where_clause_for_specific_project(project_id)
  end

  defp aggregate_permissions(user_to_permission_bindings) do
    subquery(user_to_permission_bindings)
    |> group_by([upb], [upb.user_id, upb.org_id, upb.project_id])
    |> order_by([upb], upb.user_id)
    |> select([upb], %{
      user_id: upb.user_id,
      org_id: upb.org_id,
      project_id: upb.project_id,
      permission_names: fragment("string_agg(?, ',')", upb.permission_names)
    })
  end

  ###
  ### Helper functions
  ###

  defp validate_role_binding_identification(role_binding_identification) do
    with nil <- role_binding_identification[:user_id],
         nil <- role_binding_identification[:org_id],
         nil <- role_binding_identification[:project_id] do
      :error
    else
      _ -> :ok
    end
  end

  defp add_where_clause_for_specific_org(query, nil), do: query

  defp add_where_clause_for_specific_org(query, org_id),
    do: query |> where([srb], srb.org_id == ^org_id)

  defp add_where_clause_for_specific_project(query, nil), do: query

  defp add_where_clause_for_specific_project(query, :is_nil) do
    query |> where([srb], is_nil(srb.project_id))
  end

  defp add_where_clause_for_specific_project(query, :is_not_nil) do
    query |> where([srb], not is_nil(srb.project_id))
  end

  defp add_where_clause_for_specific_project(query, project_id),
    do: query |> where([srb], srb.project_id == ^project_id)
end
