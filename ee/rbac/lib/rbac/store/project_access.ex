defmodule Rbac.Store.ProjectAccess do
  @moduledoc """
    This module is used for communication with key-value store that contains list of project any user has
    access to within the given organization.
    Key is in format: user:{user_id}_org:{org_id}
    Value is comma separated list of project id
  """
  require Logger

  import Ecto.Query
  alias Rbac.Repo.SubjectRoleBinding
  alias Rbac.RoleBindingIdentification, as: RBI

  @store_backend Application.compile_env(:rbac, :key_value_store_backend)
  @project_access_store_name Application.compile_env(:rbac, :project_access_store_name)

  @spec get_list_of_projects(Ecto.UUID.t(), Ecto.UUID.t()) :: list(Ecto.UUID.t())
  def get_list_of_projects(user_id, org_id) do
    key = "user:#{user_id}_org:#{org_id}"

    {:ok, rbi} = RBI.new(user_id: user_id, org_id: org_id)

    if Rbac.Store.UserPermissions.read_user_permissions(rbi) =~ "project.view" do
      {:ok, project_ids} = Rbac.Store.Project.list_projects(org_id)
      project_ids
    else
      case @store_backend.get(@project_access_store_name, key) do
        {:ok, nil} ->
          Logger.error("[Project Access Store] Key #{key} not found in the store")
          []

        {:error, err_msg} ->
          Logger.error(
            "[Project Access Store] Error while fetching from the store: #{inspect(err_msg)}"
          )

          Watchman.increment("project_access_cache_error")
          []

        {:ok, projects} ->
          String.split(projects, ",") |> Enum.uniq()
      end
    end
  rescue
    e ->
      Logger.error("[Project Access Store] Error while fetching from the store: #{inspect(e)}")
      Watchman.increment("project_access_cache_error")
      []
  end

  @spec remove_project_access(RBI.t()) ::
          :ok | {:error, String.t()}
  def remove_project_access(%RBI{} = rbi) do
    query = gen_user_to_list_of_projects_per_org_query(rbi)

    user_org_projects = query |> Rbac.Repo.all()
    keys = Enum.map(user_org_projects, &"user:#{&1[:user_id]}_org:#{&1[:org_id]}")

    case @store_backend.delete(@project_access_store_name, keys) do
      {:ok, no_deleted_entities} ->
        Logger.info(
          "[Project Access Store] Removed #{no_deleted_entities} keys for rbi #{inspect(rbi)}"
        )

        :ok

      {:error, err_msg} ->
        Logger.error(
          "[Project Access Store] Error while removing keys for rbi #{inspect(rbi)}: #{err_msg}"
        )

        {:error, err_msg}
    end
  end

  @spec remove_project_access(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          :ok | {:error, String.t()}
  def remove_project_access(user_id, org_id, project_id) do
    key = "user:#{user_id}_org:#{org_id}"

    case @store_backend.get(@project_access_store_name, key) do
      {:error, err_msg} ->
        Logger.error(
          "[Project Access Store] Error while fetching from the store: #{inspect(err_msg)}"
        )

        Watchman.increment("project_access_cache_error")
        {:error, err_msg}

      {:ok, nil} ->
        Logger.warning(
          "[Project Access Store] Tried removing #{project_id} from the key #{key}," <>
            " but that key isn't present in the store at all."
        )

        :ok

      {:ok, projects} ->
        projects = String.split(projects, ",")
        no_projects_before = length(projects)
        projects = List.delete(projects, project_id)
        no_projects_after = length(projects)

        if no_projects_after != no_projects_before - 1 do
          Logger.error(
            "Tried deleting project #{project_id} from key #{key}." <>
              "No of projects before deleting: #{no_projects_before}, and after: no_projects_after"
          )

          Watchman.increment("project_access_cache_error")
          {:error, "Project removal unseccessful"}
        else
          if projects == [] do
            @store_backend.delete(@project_access_store_name, [key])
          else
            projects = Enum.join(projects, ",")
            @store_backend.put(@project_access_store_name, key, projects)
          end

          :ok
        end
    end
  end

  @spec add_project_access(RBI.t()) :: :ok | {:error, String.t()}
  def add_project_access(%RBI{} = rbi) do
    query = gen_user_to_list_of_projects_per_org_query(rbi)

    user_org_projects = query |> Rbac.Repo.all()
    keys = Enum.map(user_org_projects, &"user:#{&1[:user_id]}_org:#{&1[:org_id]}")
    values = Enum.map(user_org_projects, & &1[:project_ids])

    case @store_backend.put_batch(@project_access_store_name, keys, values) do
      {:ok, no_of_inserts} ->
        Logger.info(
          "[Project Access Store] Inserted #{no_of_inserts} pairs for rbi #{inspect(rbi)}"
        )

        :ok

      {:error, err_msg} ->
        Logger.error(
          "[Project Access Store] Error while adding pairs for rbi #{inspect(rbi)}. Error message: #{inspect(err_msg)}"
        )

        {:error, err_msg}
    end
  end

  @spec add_project_access(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          :ok | {:error, String.t()}
  def add_project_access(user_id, org_id, project_id) do
    Logger.info(
      "[Project Access Store] Adding access to project #{project_id} within org #{org_id} to the user #{user_id}"
    )

    key = "user:#{user_id}_org:#{org_id}"

    case @store_backend.get(@project_access_store_name, key) do
      {:error, err_msg} ->
        Logger.error(
          "[Project Access Store] Error while fetching from the store: #{inspect(err_msg)}"
        )

        Watchman.increment("project_access_cache_error")
        {:error, err_msg}

      {:ok, nil} ->
        {:ok, _project_id} = @store_backend.put(@project_access_store_name, key, project_id)
        :ok

      {:ok, projects} ->
        if projects =~ project_id do
          :ok
        else
          projects = projects <> "," <> project_id
          {:ok, _project_id} = @store_backend.put(@project_access_store_name, key, projects)
          :ok
        end
    end
  end

  def delete_all do
    case @store_backend.clear(@project_access_store_name) do
      {:ok, _} -> :ok
      {:errer, _} -> :error
    end
  end

  def recalculate_entire_key_value_store(batch_size \\ 20_000) do
    Logger.info("[Project Access Store] Recalculating entire key-value store")

    @store_backend.clear(@project_access_store_name)

    {:ok, _} = GenServer.start(Rbac.Utils.Counter, 0, name: :batch_inserts_counter)

    Rbac.Repo.transaction(
      fn ->
        generate_db_stream(batch_size)
        |> Stream.chunk_every(batch_size)
        |> Stream.map(&write_batch_to_store/1)
        |> Stream.run()
      end,
      timeout: 100_000
    )

    GenServer.stop(:batch_inserts_counter)
  end

  defp write_batch_to_store(user_org_projects) when is_list(user_org_projects) do
    count = GenServer.call(:batch_inserts_counter, {:increment, length(user_org_projects)})
    Logger.info("[Project Access Store] Wrote #{count} key-value pairs")

    keys = Enum.map(user_org_projects, &"user:#{&1[:user_id]}_org:#{&1[:org_id]}")
    values = Enum.map(user_org_projects, & &1[:project_ids])

    case @store_backend.put_batch(@project_access_store_name, keys, values) do
      {:ok, no_of_inserts} ->
        Logger.info("[Project Access Store] Batch inserted #{no_of_inserts} into the cache")
        :ok

      {:error, err_msg} ->
        Logger.error(
          "[Project Access Store] Error while using batch_put. Error message: #{inspect(err_msg)}"
        )

        :error
    end
  end

  defp generate_db_stream(batch_size) do
    # Empty rbi, that will result in query that will generate user-to-projects for all users
    {:ok, rbi} = Rbac.RoleBindingIdentification.new()
    query = gen_user_to_list_of_projects_per_org_query(rbi)

    Rbac.Repo.stream(query, max_rows: batch_size, timeout: 60_000)
  end

  defp gen_user_to_list_of_projects_per_org_query(rbi) do
    user_to_subject_bindings = Rbac.Repo.Queries.user_to_subject_bindings_query(rbi.user_id)

    SubjectRoleBinding
    |> join(:inner, [srb], u in subquery(user_to_subject_bindings),
      on: u.subject_id == srb.subject_id
    )
    |> where([srb], not is_nil(srb.project_id))
    |> group_by([srb, u], [srb.org_id, u.user_id])
    |> select([srb, u], %{
      user_id: u.user_id,
      org_id: srb.org_id,
      project_ids: fragment("string_agg(?::text, ',')", srb.project_id)
    })
    |> add_where_clause_for_specific_org(rbi.org_id)
  end

  defp add_where_clause_for_specific_org(query, nil), do: query

  defp add_where_clause_for_specific_org(query, org_id),
    do: query |> where([srb], srb.org_id == ^org_id)
end
