defmodule Rbac.Store.UserPermissions do
  @moduledoc """
    This module is used for all communication with key-value store for list of permissions each user has within
    the organization or project.
    Key is in format: user:{user_id}_org:{org_id}_project:{*|project_id}
    Value is comma separated list of permissions
  """

  require Logger
  alias Rbac.ComputePermissions
  alias Rbac.RoleBindingIdentification, as: RBI

  @user_permissions_store_name Application.compile_env(:rbac, :user_permissions_store_name)
  @store_backend Application.compile_env(:rbac, :key_value_store_backend)
  @no_permissions_string ""

  @doc """
    Function that takes RoleBindingIdentification struct as an argument

    Returns:
    A string with all users permissions (for specific org or project) separated with commas (,)
  """
  @spec read_user_permissions(RBI) :: String.t()
  def read_user_permissions(role_binding_identification) do
    if role_binding_identification[:user_id] == nil do
      Logger.error(
        "[User-Permissions Store] Trying to read user permissions, but nil user_id was given to the read_user_permissions function."
      )

      Logger.warning(
        "[User-Permissions Store] Object given to the function: #{inspect(role_binding_identification)}"
      )

      @no_permissions_string
    else
      possible_cache_keys = RBI.generate_all_possible_keys(role_binding_identification)
      all_permissions = Enum.map_join(possible_cache_keys, ",", &read/1)
      all_permissions |> cleanup()
    end
  end

  defp cleanup(permissions) do
    if permissions |> String.replace(",", "") == "" do
      @no_permissions_string
    else
      permissions
    end
  end

  @doc """
    Function that takes RoleBindingIdentification struct as an argument, and writes all permissions calculated
    for that user/org/project into the cache

    Returns
      :ok - if all key value pairs were successfully written to the cache
      :error - if permissions could not be calculated or at least one permission wasnt written to the cache
  """
  @spec add_permissions(RBI) :: :ok | :error
  def add_permissions(role_binding_identification \\ %RBI{}) do
    case ComputePermissions.compute_permissions(role_binding_identification) do
      {:ok, data} ->
        write_results =
          Enum.map(data, fn row ->
            {:ok, rbi} = RBI.new(row)
            write(rbi, row[:permission_names])
          end)

        successful_writes = write_results |> Enum.count(&(&1 == :ok))
        failed_writes = write_results |> Enum.count(&(&1 == :error))

        if failed_writes == 0 do
          Logger.info(
            "[User-Permissions Store] Successfully wrote #{successful_writes} permissions to the cache"
          )

          :ok
        else
          Logger.error("[User-Permissions Store] #{failed_writes} failed writes.")

          :error
        end

      {:error, error} ->
        Logger.error(
          "[User-Permissions Store add_permissions] Could not calculate user role bindings " <>
            "from database with argument: #{inspect(role_binding_identification)}"
        )

        Logger.error(error)
        :error
    end
  end

  @doc """
    Function that takes RoleBindingIdentification struct as an argument, gets all the keys releted to those users/orgs/projects
    from database, and removes them from the cache

    IMPORTANT: Since keys-to-be-deleted are calculated from the database, this function has to be called before subject_role_bindings
    are removed from the database, otherwise keys that were removed from db wont be deleted from the cache!

    Returns
      :ok - if all key value pairs were successfully written to the cache
      :error - if permissions could not be calculated or at least one permission wasnt written to the cache
  """
  @spec remove_permissions(RBI) :: :ok | :error
  def remove_permissions(role_binding_identification) do
    case ComputePermissions.compute_permissions(role_binding_identification) do
      {:ok, data} ->
        keys_to_delete =
          Enum.map(data, fn row ->
            {:ok, rbi} = RBI.new(row)
            RBI.generate_cache_key(rbi)
          end)

        if keys_to_delete != [] do
          case @store_backend.delete(@user_permissions_store_name, keys_to_delete) do
            {:ok, no_of_keys_removed} ->
              Logger.info(
                "[User-Permissions Store] Removed #{no_of_keys_removed} keys from the cache"
              )

              :ok

            {:error, msg} ->
              Logger.error("[User-Permissions Store] Error: " <> msg)
              :error
          end
        else
          :ok
        end

      {:error, error} ->
        Logger.error(
          "[User-Permissions Store] Could not calculate user role bindings " <>
            "from database with argument:#{inspect(role_binding_identification)}"
        )

        Logger.error(error)
        :error
    end
  end

  @doc """
    NOTE: This function should not be used on regular basis, just when something goes
    wrong with the cache server.

    Since recalculatin entire cache is too memory intensive and crashes the container,
    this function does it in batches.
  """
  def recalculate_entire_cache(batch_size \\ 10_000) do
    Logger.info("[Recalculate_entire_cache]")

    delete_all()
    {:ok, _} = GenServer.start(Rbac.Utils.Counter, 0, name: :batch_inserts_counter)

    Rbac.Repo.transaction(
      fn ->
        ComputePermissions.compute_all_permissions(batch_size)
        |> Stream.chunk_every(batch_size)
        |> Stream.map(&prepare_batch_data_for_cache_batch/1)
        |> Stream.run()
      end,
      timeout: 500_000
    )

    GenServer.stop(:batch_inserts_counter)
  end

  defp prepare_batch_data_for_cache_batch(user_permissions_batch) do
    count = GenServer.call(:batch_inserts_counter, {:increment, length(user_permissions_batch)})
    Logger.info("Wrote #{count} permissions to cache")

    role_binding_information =
      Enum.map(user_permissions_batch, fn user_permission ->
        {:ok, rbi} = RBI.new(user_permission)
        rbi
      end)

    permissions =
      Enum.map(user_permissions_batch, fn user_permission ->
        user_permission[:permission_names]
      end)

    write(role_binding_information, permissions)
  end

  @spec delete_all() :: :ok | :error
  def delete_all do
    case @store_backend.clear(@user_permissions_store_name) do
      {:ok, _} -> :ok
      {:errer, _} -> :error
    end
  end

  @spec read(String.t()) :: String.t()
  defp read(key) do
    case @store_backend.get(@user_permissions_store_name, key) do
      {:ok, nil} ->
        # This is expected behavior, as cache misses will happen on more or less every read. This happens
        # beacuse there are 3 possible cache keys where permisions can be stored (function 'generate_all_keys'
        # in RoleBindingIdentification module calculates those keys). Some of those keys will store permissions, some
        # wont exist. It's a problem when non of those 3 keys exist in cache! (Empty string returned represents
        # no permissions)
        ""

      {:ok, permissions} ->
        permissions

      {:error, description} ->
        Watchman.increment("rbac_cache.read_error")
        Logger.error("[User-Permissions Store] Read error: '#{description}'")
        ""
    end
  rescue
    e ->
      Watchman.increment("rbac_cache.read_error")
      Logger.error("[User-Permissions Store] Read error: '#{inspect(e)}'")
      ""
  end

  @spec write(list(RBI), list(String.t())) :: :ok | :error
  defp write(role_binding_identification, permissions)
       when is_list(role_binding_identification) and is_list(permissions) do
    keys =
      Enum.map(role_binding_identification, fn rbi ->
        RBI.generate_cache_key(rbi)
      end)

    case @store_backend.put_batch(@user_permissions_store_name, keys, permissions,
           timeout: 60_000
         ) do
      {:ok, no_of_inserts} ->
        Logger.info("[User-Permissions Store] Batch inserted #{no_of_inserts} into the cache")
        :ok

      {:error, err_msg} ->
        Logger.error(
          "[User-Permissions Store] Error while using batch_put. Error message: #{inspect(err_msg)}"
        )

        :error
    end
  end

  @spec write(RBI, String.t()) :: :ok | :error
  defp write(role_binding_identification, permissions) do
    key = RBI.generate_cache_key(role_binding_identification)

    case @store_backend.put(@user_permissions_store_name, key, permissions) do
      {:ok, _} ->
        Watchman.increment("rbac_cache.write_cache")
        :ok

      {:error, err_msg} ->
        Watchman.increment("rbac_cache.write_error")

        Logger.error(
          "[User-Permissions Store] Error while trying to write to store for key: #{key} and value: #{permissions}. " <>
            "Error message: #{inspect(err_msg)}"
        )

        :error
    end
  end
end
