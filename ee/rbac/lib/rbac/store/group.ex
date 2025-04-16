defmodule Rbac.Store.Group do
  require Logger

  alias Rbac.RoleBindingIdentification, as: RBI
  alias Rbac.Store.{UserPermissions, ProjectAccess}
  import Ecto.Query

  @spec fetch_all_org_groups(String.t(), integer(), integer()) :: [map()]
  def fetch_all_org_groups(org_id, page_no, page_size) do
    Rbac.Repo.Group
    |> where([g], g.org_id == ^org_id)
    |> join(:inner, [g], s in assoc(g, :subject))
    |> order_by([_g, s], [s.name, s.id])
    |> limit(^page_size)
    |> offset(^(page_no * page_size))
    |> select([g, s], %{id: g.id, org_id: g.org_id, name: s.name, description: g.description})
    |> Rbac.Repo.all()
  end

  def fetch_group(group_id) do
    Rbac.Repo.Group
    |> where([g], g.id == ^group_id)
    |> join(:inner, [g], s in assoc(g, :subject))
    |> select([g, s], %{id: g.id, org_id: g.org_id, name: s.name, description: g.description})
    |> Rbac.Repo.one()
    |> case do
      nil -> {:error, :not_found}
      group -> {:ok, group}
    end
  end

  def create_group(nil, _org_id, _creator_id), do: {:error, :group_data_not_provided}

  def create_group(group, org_id, creator_id) do
    alias Rbac.Repo.{Group, Subject}

    group_id = Ecto.UUID.generate()

    subject_changeset =
      Subject.changeset(%Subject{}, %{id: group_id, name: group.name, type: "group"})

    group_changeset =
      Group.changeset(%Group{}, %{
        id: group_id,
        org_id: org_id,
        description: group.description,
        creator_id: creator_id
      })

    ecto_transaction =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:subject, subject_changeset)
      |> Ecto.Multi.insert(:group, group_changeset)

    case execute_transaction(ecto_transaction, "create_group") do
      :ok -> fetch_group(group_id)
      error_tuple -> error_tuple
    end
  end

  @spec add_to_group(Rbac.Repo.Group.t(), String.t()) :: :ok | {:error, String.t()}
  def add_to_group(group, member_id) do
    Watchman.benchmark("groups.add_member.duration", fn ->
      {:ok, rbi} = RBI.new(user_id: member_id, org_id: group.org_id)

      ecto_transaction =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:check_if_user_in_org, fn _repo, _changeset ->
          if Rbac.RoleManagement.user_part_of_org?(member_id, group.org_id) do
            {:ok, :user_in_group}
          else
            {:error, :user_not_in_org}
          end
        end)
        |> Ecto.Multi.insert(:insert_user_group_binding, %Rbac.Repo.UserGroupBinding{
          group_id: group.id,
          user_id: member_id
        })
        |> Ecto.Multi.run(:update_user_permissions_store, fn _, _ -> add_user_permissions(rbi) end)
        |> Ecto.Multi.run(:add_project_access, fn _, _ -> add_project_access(rbi) end)

      execute_transaction(ecto_transaction, "add_member")
    end)
  end

  @spec remove_from_group(Rbac.Repo.Group.t(), String.t()) :: :ok | {:error, String.t()}
  def remove_from_group(group, member_id) do
    Watchman.benchmark("groups.remove_member.duration", fn ->
      {:ok, rbi} = RBI.new(user_id: member_id, org_id: group.org_id)

      ecto_transaction =
        Ecto.Multi.new()
        |> Ecto.Multi.run(:remove_user_permissions, fn _, _ -> remove_user_permissions(rbi) end)
        |> Ecto.Multi.run(:remove_project_access, fn _, _ -> clear_project_access(rbi) end)
        |> Ecto.Multi.delete_all(
          :delete_user_group_binding,
          Rbac.Repo.UserGroupBinding
          |> where([ugb], ugb.group_id == ^group.id and ugb.user_id == ^member_id)
        )
        |> Ecto.Multi.run(:update_user_permissions_store, fn _, _ -> add_user_permissions(rbi) end)
        |> Ecto.Multi.run(:add_project_access, fn _, _ -> add_project_access(rbi) end)

      execute_transaction(ecto_transaction, "remove_member")
    end)
  end

  @doc """
    Finds all the groups a given user belongs to (within the given organization)
    and creates requests for asynchronously removing the user from each of them
  """
  def remove_member_from_all_org_groups(member_id, org_id, requester_id) do
    Rbac.Repo.UserGroupBinding
    |> where([ugb], ugb.user_id == ^member_id)
    |> join(:inner, [ugb], g in assoc(ugb, :group))
    |> where([_, g], g.org_id == ^org_id)
    |> select([ugb, _], ugb.group_id)
    |> Rbac.Repo.all()
    |> Enum.each(&create_request(member_id, &1, :remove_user, requester_id))
  end

  def modify_metadata(group_id, "", ""), do: fetch_group(group_id)

  def modify_metadata(group_id, new_name, new_description) do
    ecto_transaction =
      Ecto.Multi.new()
      |> maybe_add_subject_update(group_id, new_name)
      |> maybe_add_group_update(group_id, new_description)

    case execute_transaction(ecto_transaction, "modify_group") do
      :ok -> fetch_group(group_id)
      error_tuple -> error_tuple
    end
  end

  @spec destroy(String.t()) :: :ok | {:error, atom() | String.t()}
  def destroy(group_id) do
    Watchman.benchmark("groups.destroy.duration", fn ->
      case fetch_group(group_id) do
        {:ok, group} ->
          {:ok, rbi} = RBI.new(org_id: group.org_id)

          ecto_transaction =
            Ecto.Multi.new()
            |> Ecto.Multi.run(:clear_all_permissions, fn _, _ -> remove_user_permissions(rbi) end)
            |> Ecto.Multi.run(:clear_all_project_access, fn _, _ -> clear_project_access(rbi) end)
            |> Ecto.Multi.delete_all(
              :delete_user_group_bindings,
              Rbac.Repo.UserGroupBinding |> where([ugb], ugb.group_id == ^group_id)
            )
            |> Ecto.Multi.delete_all(
              :delete_subject_role_bindings,
              Rbac.Repo.SubjectRoleBinding |> where([srb], srb.subject_id == ^group_id)
            )
            |> Ecto.Multi.delete_all(
              :delete_group,
              Rbac.Repo.Group |> where([g], g.id == ^group_id)
            )
            |> Ecto.Multi.delete_all(
              :delete_subject,
              Rbac.Repo.Subject |> where([s], s.id == ^group_id)
            )
            |> Ecto.Multi.run(:recalculate_all_permissions, fn _, _ ->
              add_user_permissions(rbi)
            end)
            |> Ecto.Multi.run(:recalculate_all_project_access, fn _, _ ->
              add_project_access(rbi)
            end)

          execute_transaction(ecto_transaction, "destroy_group")

        {:error, :not_found} ->
          :ok
      end
    end)
  end

  #
  # Helper funcs
  #

  defp execute_transaction(ecto_transaction, action_name) do
    case Rbac.Repo.transaction(ecto_transaction, timeout: 60_000) do
      {:ok, _} ->
        :ok

      {:error, step_with_error, error_msg, _} ->
        Logger.error(
          "[Groups] Could not #{action_name}. " <>
            "Multi' step that caused the error: #{inspect(step_with_error)}. Error_msg: #{inspect(error_msg)}."
        )

        Watchman.increment("groups.#{action_name}.failure")
        {:error, error_msg}
    end
  end

  defp maybe_add_subject_update(ecto_multi, subject_id, new_name) do
    if new_name == "" do
      ecto_multi
    else
      subject = Rbac.Repo.Subject.find_by_id(subject_id)

      ecto_multi
      |> Ecto.Multi.update(:subject, subject |> Rbac.Repo.Subject.changeset(%{name: new_name}))
    end
  end

  defp maybe_add_group_update(ecto_multi, group_id, new_description) do
    alias Rbac.Repo.Group
    import Ecto.Query, only: [where: 3]

    if new_description == "" do
      ecto_multi
    else
      group = Group |> where([g], g.id == ^group_id) |> Rbac.Repo.one()

      ecto_multi
      |> Ecto.Multi.update(:group, group |> Group.changeset(%{description: new_description}))
    end
  end

  defp add_user_permissions(rbi) do
    if UserPermissions.add_permissions(rbi) == :ok do
      {:ok, :cache_successful}
    else
      {:error, :cache_refresh_error}
    end
  end

  defp add_project_access(rbi) do
    if ProjectAccess.add_project_access(rbi) == :ok do
      {:ok, :added_keys_from_project_access_store}
    else
      {:error, :cant_add_project_acces_to_store}
    end
  end

  defp remove_user_permissions(rbi) do
    if UserPermissions.remove_permissions(rbi) == :ok do
      {:ok, :cache_remove_successful}
    else
      {:error, :cant_remove_permissions_from_cache}
    end
  end

  defp clear_project_access(rbi) do
    if ProjectAccess.remove_project_access(rbi) == :ok do
      {:ok, :removed_keys_from_project_access_store}
    else
      {:error, :cant_remove_keys_from_project_access_store}
    end
  end

  defdelegate create_request(user_id_or_ids, group_id, action, requester_id),
    to: Rbac.Repo.GroupManagementRequest,
    as: :create_new_request
end
