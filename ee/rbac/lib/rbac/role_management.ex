defmodule Rbac.RoleManagement do
  require Logger

  import Ecto.Query
  import Rbac.Utils.Common, only: [valid_uuid?: 1]

  alias Rbac.RoleBindingIdentification, as: RBI
  alias Rbac.Repo.Queries, as: Queries
  alias Rbac.Store.{UserPermissions, ProjectAccess}

  alias Rbac.Repo.{
    OrgRoleToProjRoleMapping,
    SubjectRoleBinding,
    Collaborator,
    Project,
    User,
    RbacUser,
    Subject
  }

  @type uuid :: Ecto.UUID.t()
  @type subject_role_bindings :: [
          %{
            subject_id: uuid,
            org_id: uuid,
            name: String.t(),
            type: String.t(),
            role_bindings: [
              %{
                binding_source: String.t(),
                id: uuid,
                inserted_at: NaiveDateTime.t(),
                updated_at: NaiveDateTime.t(),
                org_id: uuid,
                project_id: uuid,
                subject_id: uuid,
                role_id: uuid
              }
            ]
          }
        ]

  @doc """
    The function fetches all of the subject-role bindings based on the filters applied.
    RBI specifies for which user/org/project to fetch role bindings.
    Function returns a pagenated list, and the number of pages there are for this specific filter

    Return: subject_role_bindings.t()
  """
  @spec fetch_subject_role_bindings(RBI.t(), keyword) :: {subject_role_bindings, non_neg_integer}
  def fetch_subject_role_bindings(rbi, filter_opts \\ []) do
    query =
      SubjectRoleBinding
      |> add_inherited_roles(rbi.org_id, rbi.project_id)
      |> from
      |> add_where_for_user(rbi.user_id)
      |> add_where_for_org(rbi.org_id)
      |> add_where_for_project(rbi.project_id)
      |> add_where_for_role(filter_opts[:role_id])
      |> add_where_for_binding_source(filter_opts[:binding_source])
      |> join(:left, [srb], s in Subject, on: srb.subject_id == s.id)
      |> add_search_by_name(filter_opts[:subject_name])
      |> add_search_by_subject_type(filter_opts[:subject_type])
      |> group_by([srb, ru], [ru.id, srb.org_id, ru.name, ru.type])
      |> select([srb, ru], %{
        subject_id: ru.id,
        org_id: srb.org_id,
        name: ru.name,
        type: ru.type,
        role_bindings: fragment("json_agg(?)", srb)
      })
      |> order_by([_, ru], [ru.name, ru.id])

    {pg_size, pg_no} = extract_pagination_info(filter_opts)
    role_bindings = query |> limit(^pg_size) |> offset(^(pg_no * pg_size)) |> Rbac.Repo.all()
    total_bindings = query |> subquery() |> Rbac.Repo.aggregate(:count, :subject_id)
    total_pages = (total_bindings / pg_size) |> Float.ceil() |> round()

    {role_bindings, total_pages}
  end

  @doc """
    The function fetches the number of subject-role bindings based on the filters applied.
    RBI specifies for which user/org/project to fetch role bindings.
  """
  @spec count_subject_role_bindings(RBI.t()) :: non_neg_integer()
  def count_subject_role_bindings(rbi) do
    SubjectRoleBinding
    |> add_inherited_roles(rbi.org_id, rbi.project_id)
    |> from
    |> add_where_for_user(rbi.user_id)
    |> add_where_for_org(rbi.org_id)
    |> add_where_for_project(rbi.project_id)
    |> select([srb], count(srb.id))
    |> Rbac.Repo.one()
  end

  @page_size 20
  defp extract_pagination_info(opts) do
    page_size = if opts[:page_size] in [nil, 0], do: @page_size, else: opts[:page_size]
    page_no = if opts[:page_no] == nil, do: 0, else: opts[:page_no]
    {page_size, page_no}
  end

  @doc """
    Check if given user has the role assigned within a given org or project.
    The function checks if role is assigned directly or indirectly (through role inheritance or org to proj role mappings)

    Arguments:
    - rbi
          {
            subject_id  - [required] Id of subject for whom we are checking role assignment.
            org_id      - [required] Org within which the assignment exists.
            project_id  - [optional] Project within which role assignment exists. Required only if we are checking
                        role assignment for project-level role
          }
    - role_id  - [required] Id of the role we are checking for.
  """
  @spec has_role(RBI, String.t()) :: true | false
  def has_role(rbi, role_id) do
    case verify_input_for_new_role(rbi.user_id, rbi.org_id, rbi.project_id, role_id) do
      {:ok, nil} ->
        user_to_subject_bindings = Queries.user_to_subject_bindings_query(rbi.user_id)
        role_inheritance_tree = Queries.role_inheritance_and_mappings_query()

        project_where_clause =
          if valid_uuid?(rbi.project_id) do
            &where(&1, [srb], srb.project_id == ^rbi.project_id or is_nil(srb.project_id))
          else
            &add_where_for_project(&1, rbi.project_id)
          end

        SubjectRoleBinding
        |> join(:inner, [srb], u in subquery(user_to_subject_bindings),
          on: u.subject_id == srb.subject_id
        )
        |> join(:inner, [srb], rit in subquery(role_inheritance_tree),
          on: rit.inheriting_role_id == srb.role_id
        )
        |> add_where_for_org(rbi.org_id)
        |> project_where_clause.()
        |> where(
          [_, _, rit],
          rit.inherited_role_id == ^role_id or rit.mapped_proj_role_id == ^role_id
        )
        |> Rbac.Repo.exists?()

      {:error, error_msg} ->
        Logger.warning(
          "[Role Management] Invalid input passed to has_role function. #{error_msg}"
        )

        false
    end
  end

  @doc """
    Checks whether user has any role within the given org, thus being a part of it.
  """
  @spec user_part_of_org?(String.t(), String.t()) :: boolean
  def user_part_of_org?(user_id, org_id) do
    SubjectRoleBinding
    |> from
    |> add_where_for_project(:is_nil)
    |> add_where_for_org(org_id)
    |> add_where_for_user(user_id)
    |> Rbac.Repo.exists?()
  end

  @doc """
    Function that assignes role to user within a given organization (or specific project)

    NOTE: If role binding already exists for this user-organization-project-binding_source combination,
    old role binding will be overwritten.

    Returns:
      {:ok, nil}        - If role binding is successfully written to the database
      {:error, err_msg} - If arguments aren't valid or database cant be reached
  """
  @spec assign_role(RBI, String.t(), atom) :: {:ok, nil} | {:error, String.t()}
  def assign_role(rbi, role_id, binding_source) do
    Logger.info(fn ->
      "[Role Management] Adding role for RBI #{inspect(rbi)}, binding source: #{inspect(binding_source)}"
    end)

    with {:ok, nil} <-
           verify_input_for_new_role(rbi[:user_id], rbi[:org_id], rbi[:project_id], role_id),
         true <- rbi[:project_id] == nil or user_part_of_org?(rbi[:user_id], rbi[:org_id]) do
      case [
             %{
               role_id: role_id,
               subject_id: rbi[:user_id],
               org_id: rbi[:org_id],
               project_id: rbi[:project_id],
               binding_source: binding_source
             }
           ]
           # If you want to assign a project_level role, user must already be member of the org
           |> assign_roles(rbi) do
        {:ok, nil} ->
          assigned_role = Rbac.Repo.RbacRole.get_role_by_id(role_id)

          if assigned_role.scope.scope_name == "org_scope" do
            Logger.info(fn ->
              "User #{inspect(rbi[:user_id])} was assigned org_level roles. " <>
                "Checking if user is collaborator on any of organizations projects"
            end)

            assign_project_roles_to_repo_collaborators(rbi)
          else
            {:ok, nil}
          end

        error_tuple ->
          error_tuple
      end
    else
      false ->
        {:error,
         "Project level role cant be assigned to a user that isn't already organization member"}

      error_tuple ->
        error_tuple
    end
  end

  @doc """
    Takes a RoleBindingInformation struct and retracts a role that specific user has within the org or project.
    Fileds in RoleBindingInformation struct can be nil, but this function expects every field to be set.
    user_id and org_id must be valid uuids, and project_id can be :is_nil, if we are retracting
    org level role, or uuid of the project from which user's role is being retracted.
  """
  @spec retract_roles(RBI, atom()) :: {:ok, nil} | {:error, String.t()}
  def retract_roles(rbi, binding_source \\ nil) do
    Logger.info(fn ->
      "[Role Management] Retracting roles for RBI #{inspect(rbi)}, binding source: #{inspect(binding_source)}"
    end)

    case Ecto.Multi.new()
         |> Ecto.Multi.run(:remove_user_permissions_from_store, fn _repo, _changes ->
           case UserPermissions.remove_permissions(rbi) do
             :ok ->
               {:ok, :cache_remove_successful}

             :error ->
               {:error, :cant_remove_permissions_from_cache}
           end
         end)
         |> Ecto.Multi.run(:remove_project_access, fn _repo, _changes ->
           case ProjectAccess.remove_project_access(rbi) do
             :ok ->
               {:ok, :removed_keys_from_project_access_store}

             err_tuple ->
               err_tuple
           end
         end)
         |> Ecto.Multi.delete_all(
           :delete_subject_role_bindings,
           Rbac.Repo.SubjectRoleBinding
           |> from
           |> add_where_for_org(rbi[:org_id])
           |> add_where_for_project(rbi[:project_id])
           |> add_where_for_user(rbi[:user_id])
           |> add_where_for_binding_source(binding_source)
         )
         # Why are permissions added to cache inside 'retract_role' function:
         # Inside the cache all users permissions are under one key, no matter from which role assignment they come.
         # In case user has multiple roles within the same project/org, and only one is retracted, it is not possible
         # to alter the cahce and remove only some permissions. Entire cache entry must be removed and added after the
         # role assignment is deleted from db.
         |> Ecto.Multi.run(:update_user_permissions_store, fn _repo, _changeset ->
           update_user_permissions_store(rbi)
         end)
         |> Ecto.Multi.run(:add_project_access, fn _repo, _changeset ->
           case ProjectAccess.add_project_access(rbi) do
             :ok ->
               {:ok, :added_keys_from_project_access_store}

             err_tuple ->
               err_tuple
           end
         end)
         |> Rbac.Repo.transaction(timeout: 60_000) do
      {:ok, _} ->
        {:ok, nil}

      {:error, step_with_error, error_msg, _} ->
        Logger.error(
          "[Rbac RoleManagement] Could not retreact assigned roles. " <>
            "'Multi' step that caused the errer: #{step_with_error}. Error_msg: #{error_msg}."
        )

        {:error, error_msg}
    end
  end

  @doc """
    Get collaborators list for a given project, and assign each collaborator a project level
    rols based on the RepoToRoleMapping.
  """
  @spec assign_project_roles_to_repo_collaborators(RBI.t()) :: {:ok, nil} | {:error, String.t()}
  def assign_project_roles_to_repo_collaborators(rbi) do
    rbi =
      if rbi[:project_id] == nil do
        {:ok, new_rbi} =
          RBI.new(org_id: rbi[:org_id], project_id: :is_not_nil, user_id: rbi[:user_id])

        new_rbi
      else
        rbi
      end

    Logger.info(
      "[Role Management] Assigning roles based of collaborators list for RBI: #{inspect(rbi)}"
    )

    roles_to_be_assigned =
      gen_query_to_assign_roles_to_collaborators(rbi)
      |> Rbac.Repo.all()

    list_of_subject_role_bindings =
      Enum.map(roles_to_be_assigned, fn binding ->
        %{
          role_id:
            Rbac.Repo.RepoToRoleMapping.get_project_role_from_repo_access_rights(
              binding[:org_id],
              binding[:admin_access],
              binding[:push_access],
              binding[:pull_access]
            ),
          subject_id: binding[:subject_id],
          org_id: binding[:org_id],
          project_id: binding[:project_id],
          binding_source: String.to_atom(binding[:provider])
        }
      end)
      |> Enum.filter(fn binding -> binding.role_id != nil end)

    assign_roles(list_of_subject_role_bindings, rbi)
  end

  # Takes a list of subject role bindings to insert into DB, and RoleBindingIdentification
  # for copying them inside the cache
  # IMPORTANT NOTE: This func can be used for bulk inserts of project or organization level roles,
  # but not both combined within one bulk insert
  @spec assign_roles(list(map()), RBI) :: :ok | :error
  defp assign_roles(subject_role_bindings, rbi, number_of_retries \\ 0) do
    Logger.info(
      "[Role Management] Started function for writing #{length(subject_role_bindings)} subject_role_bindings for rbi #{inspect(rbi)}."
    )

    Logger.debug(
      "[Role Management] SubjectRoleBindings: #{inspect(subject_role_bindings)}, rbi: #{inspect(rbi)}"
    )

    case Ecto.Multi.new()
         |> Ecto.Multi.insert_all(
           :insert_new_role_bindings,
           Rbac.Repo.SubjectRoleBinding,
           subject_role_bindings,
           on_conflict: :replace_all,
           conflict_target: {
             :unsafe_fragment,
             if rbi[:project_id] == nil do
               ~s<("subject_id", "org_id", "binding_source") WHERE project_id IS NULL>
             else
               ~s<("subject_id", "org_id", "project_id", "binding_source") WHERE project_id IS NOT NULL>
             end
           }
         )
         |> Ecto.Multi.run(:update_user_permissions_store, fn _repo, _changeset ->
           update_user_permissions_store(rbi)
         end)
         |> Ecto.Multi.run(:add_project_access, fn _repo, _changeset ->
           case ProjectAccess.add_project_access(rbi) do
             :ok ->
               {:ok, :added_keys_from_project_access_store}

             err_tuple ->
               err_tuple
           end
         end)
         |> Rbac.Repo.transaction(timeout: 60_000) do
      {:ok, _} ->
        Logger.debug(fn -> "[Rbac RoleManagement] Role(s) successfully assigned" end)
        {:ok, nil}

      {:error, step_with_error, error_msg, _} ->
        Logger.error(
          "[Rbac RoleManagement] Could not write SubjectRoleBinding. " <>
            "'Multi' step that caused the errer: #{step_with_error}. Error_msg: #{error_msg}."
        )

        {:error, error_msg}
    end
  rescue
    error in Postgrex.Error ->
      if Map.fetch!(Map.fetch!(error, :postgres), :code) == :foreign_key_violation and
           number_of_retries == 0 do
        Logger.error("Trying to assign role to non-existant user. Will try again in 0.5 seconds")
        :timer.sleep(500)
        assign_roles(subject_role_bindings, rbi, 1)
      else
        throw(error)
      end
  end

  defp update_user_permissions_store(rbi) do
    case UserPermissions.add_permissions(rbi) do
      :ok ->
        {:ok, :cache_successful}

      :error ->
        {:error, :cache_refresh_error}
    end
  end

  ###
  ### Helper functions
  ###

  @spec gen_query_to_assign_roles_to_collaborators(RBI.t()) :: Ecto.Query.t()
  defp gen_query_to_assign_roles_to_collaborators(rbi) do
    Collaborator
    |> join(:inner, [c], p in Project, on: c.project_id == p.project_id)
    |> add_where_for_project(rbi[:project_id])
    |> add_where_for_org(rbi[:org_id])
    |> join(:inner, [c], u in User, on: c.github_uid == u.github_uid)
    |> join(:inner, [_, _, u], ru in RbacUser, on: u.user_id == ru.id)
    |> add_where_for_user(rbi[:user_id])
    |> join(:inner, [_, _, u], srb in SubjectRoleBinding, on: u.user_id == srb.subject_id)
    |> where([_, p, _, _, srb], is_nil(srb.project_id) and srb.org_id == p.org_id)
    |> select(
      [c, p, u],
      %{
        :subject_id => u.user_id,
        :org_id => p.org_id,
        :project_id => p.project_id,
        :provider => p.provider,
        :admin_access => c.admin,
        :push_access => c.push,
        :pull_access => c.pull
      }
    )
    |> distinct(true)
  end

  defp verify_input_for_new_role(nil, _org_id, _project_id, _role_id) do
    {:error, "User id cant be nil"}
  end

  defp verify_input_for_new_role(_user_id, nil, _project_id, _role_id) do
    {:error, "Organization id cant be nil"}
  end

  defp verify_input_for_new_role(_user_id, _org_id, project_id, role_id) do
    if valid_uuid?(role_id),
      do: role_scope_matches_rest_of_data?(project_id, role_id),
      else: {:error, "Role id must be a valid uuid"}
  end

  defp role_scope_matches_rest_of_data?(project_id, role_id) do
    case Rbac.Repo.RbacRole.get_role_by_id(role_id) do
      nil ->
        {:error, "Role with id #{role_id} does not exist."}

      %{scope: %{scope_name: "project_scope"}} when is_nil(project_id) ->
        {:error, "Project id cant be nil for roles with project scope"}

      %{scope: %{scope_name: "project_scope"}} ->
        {:ok, nil}

      %{scope: %{scope_name: scope}}
      when scope in ["org_scope", "insider_scope"] and
             (is_nil(project_id) or project_id == :is_nil) ->
        {:ok, nil}

      %{scope: %{scope_name: scope}} when scope in ["org_scope", "insider_scope"] ->
        {:error, "Project id must be nil for roles with organization or insider scope"}

      %{scope: %{scope_name: scope}} ->
        Logger.error("[RoleManagement] Role #{role_id}, unrecongized scope: #{scope}.")
        {:error, "Unrecongized scope: #{scope}"}
    end
  end

  defp add_where_for_user(query, nil), do: query

  defp add_where_for_user(query, user_id) do
    case query.from.source do
      {_, Rbac.Repo.Collaborator} ->
        query |> where([_, _, _, rbac_user], rbac_user.id == ^user_id)

      _ ->
        query |> where([srb], srb.subject_id == ^user_id)
    end
  end

  defp add_where_for_org(query, nil), do: query

  defp add_where_for_org(query, org_id) do
    case query.from.source do
      {_, Rbac.Repo.Collaborator} -> query |> where([_, proj], proj.org_id == ^org_id)
      _ -> query |> where([srb], srb.org_id == ^org_id)
    end
  end

  defp add_where_for_project(query, nil), do: query

  defp add_where_for_project(query, :is_nil) do
    case query.from.source do
      {_, Rbac.Repo.Collaborator} -> query
      _ -> query |> where([srb], is_nil(srb.project_id))
    end
  end

  defp add_where_for_project(query, :is_not_nil) do
    case query.from.source do
      {_, Rbac.Repo.Collaborator} -> query
      _ -> query |> where([srb], not is_nil(srb.project_id))
    end
  end

  defp add_where_for_project(query, project_id) do
    case query.from.source do
      {_, Rbac.Repo.Collaborator} -> query |> where([c], c.project_id == ^project_id)
      _ -> query |> where([srb], srb.project_id == ^project_id)
    end
  end

  defp add_inherited_roles(query, _, project_id) when project_id in ["", nil, :is_nil], do: query

  defp add_inherited_roles(query, org_id, project_id) do
    binding_source = "inherited_from_org_role"

    org_inherited_roles =
      SubjectRoleBinding
      |> where([srb], srb.org_id == ^org_id and is_nil(srb.project_id))
      |> join(:inner, [srb], orm in OrgRoleToProjRoleMapping, on: srb.role_id == orm.org_role_id)
      |> select([srb, orm], %{
        id: srb.id,
        role_id: orm.proj_role_id,
        org_id: srb.org_id,
        project_id: type(^project_id, :binary_id),
        subject_id: srb.subject_id,
        binding_source: ^binding_source,
        inserted_at: srb.inserted_at,
        updated_at: srb.updated_at
      })

    union_all(query, ^org_inherited_roles)
    |> subquery()
  end

  defp add_where_for_binding_source(query, nil), do: query
  defp add_where_for_binding_source(query, ""), do: query

  defp add_where_for_binding_source(query, binding_source) when is_atom(binding_source) do
    query |> where([srb], srb.binding_source == ^binding_source)
  end

  defp add_where_for_role(query, nil), do: query
  defp add_where_for_role(query, ""), do: query

  defp add_where_for_role(query, role_id) do
    query |> where([srb], srb.role_id == ^role_id)
  end

  defp add_search_by_name(query, subject_name) when subject_name in ["", nil], do: query

  defp add_search_by_name(query, subject_name) do
    query |> where([_, s], fragment("? ilike ?", s.name, ^"%#{subject_name}%"))
  end

  defp add_search_by_subject_type(query, subject_type) when subject_type in ["", nil], do: query

  defp add_search_by_subject_type(query, subject_type) do
    query |> where([_, s], s.type == ^subject_type)
  end
end
