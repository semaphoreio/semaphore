defmodule Rbac.Store.RbacRole do
  require Logger
  alias Rbac.Repo
  import Ecto.Query, only: [where: 3, select: 3]
  import Ecto.Changeset, only: [apply_changes: 1]

  @doc """
    Returns: {:ok, role} if role exists within the organization,
    {:error, error_message} if not.
  """
  def fetch(role_id, org_id) do
    case fetch_role_if_it_exists(role_id, org_id) do
      {:ok, role} -> {:ok, construct_role_model(role)}
      e -> e
    end
  end

  @doc """
    Function for creating a new role, or updating an existing role.

    Arguments:
    params: keyword list of the role parameters.
      id: Id of the role. Should be present only if the role is to be updated.
      name: Name of the role.
      description: Description of the role.
      scope_id: Id of the scope that the role belongs to.
      permission_ids: list of permission ids that the role should have after it is created/updated
      maps_to_role_id: Id of the project role that the new role should map to.
                       If the filed is nil, the new role will not map to any project level role.
      inherited_role: Id of the role that the new role should inherit.
                       If the filed is nil, the new role will not inherit any role.

    Returns: {:ok, role} if successful, {:error, error_message} if not.
  """
  def create_or_update(params) do
    with params <- Keyword.reject(params, fn {_, value} -> value in [nil, ""] end),
         {:ok, role_model} <- fetch_role_if_it_exists(params[:id]),
         :ok <- validate_role_editable(role_model),
         {:ok, role_changeset} <- create_changeset(role_model, params),
         role_with_updates <- apply_changes(role_changeset),
         :ok <- validate_permissions_exist(params[:permission_ids]),
         :ok <- validate_permissions_scope(role_with_updates, params[:permission_ids]),
         :ok <- validate_role_mapping(params[:maps_to_role_id], role_with_updates),
         :ok <- validate_role_inheritance(params[:inherited_role_id], role_with_updates),
         {:ok, permission_ids} <-
           add_default_permissions(role_with_updates, params[:permission_ids]) do
      Repo.transaction(fn ->
        created_role = Repo.insert_or_update!(role_changeset)

        cleare_role_associated_data(created_role.id)
        assign_permissions_to_the_role(created_role, permission_ids)
        assign_mapped_role(created_role, params[:maps_to_role_id])
        assign_inherited_role(created_role, params[:inherited_role_id])
        recalculate_permissions(created_role, params[:id])

        construct_role_model(created_role)
      end)
    else
      error_tuple -> error_tuple
    end
  end

  @doc """
    Deletes the role if it is editable, is not assigned to anyone,
    and is not used by any other role.

    Returns: {:ok, role} if successful, {:error, error_message} if not.
  """
  def delete_role(role_id, org_id) do
    with {:ok, role} <- fetch_role_if_it_exists(role_id, org_id),
         :ok <- validate_role_editable(role),
         :ok <- validate_role_is_no_being_used(role) do
      Repo.transaction(fn ->
        cleare_role_associated_data(role.id)
        Repo.delete!(role)
      end)
    else
      error_tuple -> error_tuple
    end
  end

  @doc """
    Removes all organization roles withouth checking if they are being used.
    Should be used only when the organization has been deleted.
  """
  def remove_org_roles(org_id) do
    Repo.transaction(fn ->
      org_role_ids =
        Repo.RbacRole
        |> where([r], r.org_id == ^org_id)
        |> select([r], r.id)
        |> Repo.all()

      Logger.info(
        "[Rbac Role Repo] Removing role permission bindings for roles #{inspect(org_role_ids)}"
      )

      Repo.RolePermissionBinding
      |> where([rpb], rpb.rbac_role_id in ^org_role_ids)
      |> Repo.delete_all()

      Logger.info(
        "[Rbac Role Repo] Removing org-role to project-role mappings for roles #{inspect(org_role_ids)}"
      )

      Repo.OrgRoleToProjRoleMapping
      |> where([opm], opm.org_role_id in ^org_role_ids)
      |> Repo.delete_all()

      Logger.info(
        "[Rbac Role Repo] Removing repo-to-role mappings for org #{inspect(org_role_ids)}"
      )

      Repo.RepoToRoleMapping
      |> where([rrm], rrm.org_id == ^org_id)
      |> Repo.delete_all()

      Repo.RbacRole |> where([r], r.org_id == ^org_id) |> Repo.delete_all()
      Logger.info("[Rbac Role Repo] Removing roles for org #{inspect(org_role_ids)}")
    end)
  end

  def create_default_roles_for_organization(org_id) do
    Logger.info("[Rbac Role] Creating roles for org #{org_id}")

    Enum.each(load_from_yaml(), fn yaml_role ->
      yaml_role = Map.put(yaml_role, :org_id, org_id)

      yaml_role =
        Map.put(yaml_role, :scope_id, Repo.Scope.get_scope_by_name(yaml_role[:scope]).id)

      {:ok, role} =
        Repo.insert(
          struct(Repo.RbacRole, Map.drop(yaml_role, [:permissions, :scope, :maps_to])),
          on_conflict: {:replace, [:updated_at]},
          conflict_target: [:name, :org_id, :scope_id],
          returning: true
        )

      role_permission_bindings =
        Enum.map(yaml_role.permissions, fn permission ->
          %{
            rbac_role_id: role.id,
            permission_id: permission
          }
        end)

      Repo.insert_all(Repo.RolePermissionBinding, role_permission_bindings,
        on_conflict: :nothing,
        conflict_target: [:permission_id, :rbac_role_id]
      )
    end)

    Repo.RepoToRoleMapping.create_mappings_from_yaml(org_id)
    Repo.OrgRoleToProjRoleMapping.create_mappings_from_yaml(org_id)

    Logger.info("[Rbac Role] Roles created for org #{org_id}.")
  end

  @roles_yaml_path "./assets/roles.yaml"
  defp load_from_yaml do
    {:ok, roles_yaml} = YamlElixir.read_from_file(@roles_yaml_path)

    Enum.map(["project_scope", "org_scope"], fn scope ->
      Enum.map(roles_yaml["roles"][scope], fn role ->
        %{
          name: role["name"],
          description: role["description"],
          scope: scope,
          permissions: Enum.map(role["permissions"], &Repo.Permission.get_permission_id/1),
          # The next field will be present only for org_level roles
          maps_to: role["maps_to"]
        }
      end)
    end)
    |> List.flatten()
  end

  ###
  ### Helpre functions for create_or_update function
  ###

  defp fetch_role_if_it_exists(id, org_id \\ nil)

  defp fetch_role_if_it_exists(id, org_id) when id not in ["", nil] do
    case Repo.RbacRole.get_role_by_id(id, org_id) do
      nil -> {:error, "The role does not exist."}
      role -> {:ok, role}
    end
  end

  defp fetch_role_if_it_exists(_, _), do: {:ok, %Repo.RbacRole{}}

  defp validate_role_editable(%{editable: false}),
    do: {:error, "This is the default role and it can not be edited nor deleted."}

  defp validate_role_editable(_), do: :ok

  defp create_changeset(role_model, params) do
    params = Keyword.put(params, :editable, true)
    changeset = Repo.RbacRole.changeset(role_model, Enum.into(params, %{}))
    if changeset.valid?, do: {:ok, changeset}, else: {:error, "Some required fields are misssing"}
  end

  defp validate_permissions_exist(permission_ids) do
    no_of_permissions = length(permission_ids)

    Repo.Permission
    |> where([p], p.id in ^permission_ids)
    |> Repo.aggregate(:count, :id)
    |> case do
      ^no_of_permissions -> :ok
      _ -> {:error, "Some permissions do not exist"}
    end
  end

  defp validate_permissions_scope(%{scope_id: scope_id}, permission_ids) do
    Repo.Permission
    |> where([p], p.id in ^permission_ids and p.scope_id != ^scope_id)
    |> Repo.exists?()
    |> if do
      {:error, "Scope of some permissions does not match the scope of the role"}
    else
      :ok
    end
  end

  defp validate_role_mapping(mapped_role_id, _) when mapped_role_id == nil, do: :ok

  defp validate_role_mapping(mapped_role_id, %{scope_id: scope_id, org_id: org_id}) do
    project_scope_id = Repo.Scope.get_scope_by_name("project_scope").id
    org_scope_id = Repo.Scope.get_scope_by_name("org_scope").id

    Repo.RbacRole
    |> where([r], r.id == ^mapped_role_id)
    |> Repo.one()
    |> case do
      nil ->
        {:error, "Role passed as 'maps_to' does not exist"}

      %{org_id: mapped_role_org_id} when mapped_role_org_id != org_id ->
        {:error, "The 'maps_to' role does not belog to the same organization as the parent role"}

      %{scope_id: mapped_role_scope_id} when mapped_role_scope_id != project_scope_id ->
        {:error, "Organization level roles can not map to another organization level role"}

      _ when scope_id != org_scope_id ->
        {:error, "Only organization level roles can have a 'map_to' role"}

      _ ->
        :ok
    end
  end

  defp validate_role_inheritance(inherited_role, _) when inherited_role == nil, do: :ok

  defp validate_role_inheritance(inherited_role, %{scope_id: scope_id, org_id: org_id}) do
    Repo.RbacRole
    |> where([r], r.id == ^inherited_role)
    |> Repo.one()
    |> case do
      nil ->
        {:error, "Role passed as 'inherited_role' does not exist"}

      %{org_id: inherited_role_org_id} when inherited_role_org_id != org_id ->
        {:error, "The 'inherited_role' doesn't belog to the same organization as the parent role"}

      %{scope_id: inherited_role_org_id} when inherited_role_org_id != scope_id ->
        {:error, "Inherited role must have the same scope as the parent role"}

      _ ->
        :ok
    end
  end

  defp validate_role_is_no_being_used(role) do
    {:ok, rbi} = Rbac.RoleBindingIdentification.new(org_id: role.org_id)
    {bindings, _} = Rbac.RoleManagement.fetch_subject_role_bindings(rbi, role_id: role.id)

    cond do
      Repo.OrgRoleToProjRoleMapping |> where([m], m.proj_role_id == ^role.id) |> Repo.exists?() ->
        {:error,
         "The #{role.name} role cannot be deleted because it is used for defining some organization level roles."}

      Repo.RoleInheritance |> where([i], i.inherited_role_id == ^role.id) |> Repo.exists?() ->
        {:error,
         "The #{role.name} role cannot be deleted because it is inherited by other roles."}

      bindings != [] ->
        {:error,
         "The #{role.name} role cannot be deleted because it is currently assigned to a user."}

      true ->
        :ok
    end
  end

  @default_org_permissions ["organization.view"]
  @default_project_permissions ["project.view"]
  defp add_default_permissions(%{scope_id: scope_id}, permission_ids) do
    case Repo.Scope.get_scope_by_id(scope_id) do
      nil ->
        {:error, "Scope with id #{inspect(scope_id)} does not exist."}

      %{scope_name: scope_name} ->
        default_permission =
          if scope_name == "org_scope",
            do: @default_org_permissions,
            else: @default_project_permissions

        default_permission
        |> Enum.map(&Repo.Permission.get_permission_id/1)
        |> Enum.concat(permission_ids)
        |> Enum.uniq()
        |> (&{:ok, &1}).()
    end
  end

  defp cleare_role_associated_data(role_id) do
    Repo.RolePermissionBinding |> where([rpb], rpb.rbac_role_id == ^role_id) |> Repo.delete_all()
    Repo.OrgRoleToProjRoleMapping |> where([m], m.org_role_id == ^role_id) |> Repo.delete_all()
    Repo.RoleInheritance |> where([i], i.inheriting_role_id == ^role_id) |> Repo.delete_all()
  end

  defp assign_permissions_to_the_role(created_role, permission_ids) do
    no_of_permissions = length(permission_ids)

    {^no_of_permissions, _} =
      permission_ids
      |> Enum.map(&%{permission_id: &1, rbac_role_id: created_role.id})
      |> (&Repo.insert_all(Repo.RolePermissionBinding, &1)).()
  end

  defp assign_mapped_role(_, maps_to_role) when maps_to_role == nil, do: :ok

  defp assign_mapped_role(role, maps_to_role) do
    %Repo.OrgRoleToProjRoleMapping{
      org_role_id: role.id,
      proj_role_id: maps_to_role
    }
    |> Repo.insert!()
  end

  defp assign_inherited_role(_, inherited_role) when inherited_role == nil, do: :ok

  defp assign_inherited_role(role, inherited_role) do
    %Repo.RoleInheritance{
      inheriting_role_id: role.id,
      inherited_role_id: inherited_role
    }
    |> Repo.insert!()
  end

  defp recalculate_permissions(_, nil), do: :ok

  defp recalculate_permissions(role, _) do
    {:ok, rbi} = Rbac.RoleBindingIdentification.new(org_id: role.org_id)
    Rbac.Store.UserPermissions.add_permissions(rbi)
  end

  # Set value of `proj_role_mappoing` and `inherited_role` fields
  # to RbacRole.t() instead of [RbacRole.t()].
  # If there are no associated roles, the fields will be nil
  defp construct_role_model([]), do: nil
  defp construct_role_model([role]), do: construct_role_model(role)

  defp construct_role_model(role) do
    Repo.RbacRole.get_role_by_id(role.id)
    |> Repo.preload([:proj_role_mapping, :inherited_role])
    |> (&Map.replace!(&1, :proj_role_mapping, construct_role_model(&1.proj_role_mapping))).()
    |> (&Map.replace!(&1, :inherited_role, construct_role_model(&1.inherited_role))).()
  end
end
