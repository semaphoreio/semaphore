defmodule Rbac.Store.UserPermissions.Test do
  use Rbac.RepoCase, async: false

  import Mock
  alias Rbac.{Store.UserPermissions, ComputePermissions}
  alias Rbac.RoleBindingIdentification, as: RBI

  @user_permissions_store_name Application.compile_env(:rbac, :user_permissions_store_name)
  @store_backend Application.compile_env(:rbac, :key_value_store_backend)
  @user_id "27676bb0-dfb4-4635-a02e-d206a7faa8de"
  @user2_id "cbd70a7d-9f42-4557-bd45-47dafd891458"
  @org_id "18877e29-64c3-4051-94b9-b585b5209c2e"
  @project_id "d3cc7839-9d09-4b16-a695-15db8beec720"

  describe "read_user_permissions/1" do
    test "Successful read" do
      {:ok, rbi} = RBI.new(user_id: @user_id)

      with_mocks [
        {RBI, [],
         [
           generate_all_possible_keys: fn ^rbi ->
             ["non_existent_key1", "non_existent_key2", "non_existext_key3"]
           end,
           fetch: fn _, :user_id -> {:ok, "test_key"} end
         ]},
        {@store_backend, [],
         [get: fn @user_permissions_store_name, _ -> {:ok, "permission"} end]},
        {Watchman, [], [increment: fn "rbac_cache.hit" -> :ok end]}
      ] do
        assert UserPermissions.read_user_permissions(rbi) == "permission,permission,permission"

        assert_called_exactly(@store_backend.get(@user_permissions_store_name, :_), 3)
        assert_called_exactly(Watchman.increment("rbac_cache.miss"), 0)
      end
    end

    test "when there is no key in the store" do
      {:ok, rbi} = RBI.new(user_id: @user_id)

      with_mocks [
        {RBI, [],
         [
           generate_all_possible_keys: fn ^rbi ->
             ["non_existent_key1", "non_existent_key2", "non_existext_key3"]
           end,
           fetch: fn _, :user_id -> {:ok, "test_key"} end
         ]},
        {@store_backend, [], [get: fn @user_permissions_store_name, _ -> {:ok, nil} end]},
        {Watchman, [], [increment: fn "rbac_cache.miss" -> :ok end]}
      ] do
        assert UserPermissions.read_user_permissions(rbi) |> String.replace(",", "") == ""
        assert_called_exactly(@store_backend.get(@user_permissions_store_name, :_), 3)
      end
    end

    test "When user_id isnt given" do
      with_mocks [
        {RBI, [],
         [
           fetch: fn _, :user_id -> {:ok, nil} end
         ]},
        {@store_backend, [],
         [
           get: fn @user_permissions_store_name, key -> {:ok, "#{key}_p1,#{key}_p2"} end
         ]}
      ] do
        assert UserPermissions.read_user_permissions(%RBI{}) == ""
        assert_called_exactly(@store_backend.get(@user_permissions_store_name, :_), 0)
      end
    end
  end

  describe "add_permissions/1" do
    test "When there is new subject_role_binding" do
      permissions = "permission1,permission2"
      cache_key = "user:#{@user_id}_org:#{@org_id}_project:#{@project_id}"

      with_mocks [
        {ComputePermissions, [],
         [
           compute_permissions: fn _ ->
             {:ok,
              [
                %{
                  user_id: @user_id,
                  org_id: @org_id,
                  project_id: @project_id,
                  permission_names: permissions
                }
              ]}
           end
         ]},
        {@store_backend, [],
         [
           put: fn @user_permissions_store_name, _, _ -> {:ok, ""} end
         ]}
      ] do
        UserPermissions.add_permissions(RBI.new(project_id: @project_id))

        assert_called_exactly(
          @store_backend.put(@user_permissions_store_name, cache_key, permissions),
          1
        )
      end
    end
  end

  describe "remove_permissions/1" do
    test "When there are no permissions to delete" do
      with_mocks [
        {ComputePermissions, [],
         [
           compute_permissions: fn _ ->
             {:ok, []}
           end
         ]},
        {@store_backend, [],
         [
           delete: fn @user_permissions_store_name, _ -> {:ok, ""} end
         ]}
      ] do
        UserPermissions.remove_permissions(RBI.new(project_id: @project_id))
        assert_called_exactly(@store_backend.delete(@user_permissions_store_name, :_), 0)
      end
    end

    test "When there are multiple permissions to be removed" do
      cache_key_1 = "user:#{@user_id}_org:#{@org_id}_project:#{@project_id}"
      cache_key_2 = "user:#{@user2_id}_org:#{@org_id}_project:#{@project_id}"

      with_mocks [
        {ComputePermissions, [],
         [
           compute_permissions: fn _ ->
             {:ok,
              [
                %{
                  user_id: @user_id,
                  org_id: @org_id,
                  project_id: @project_id,
                  permission_names: "permission1"
                },
                %{
                  user_id: @user2_id,
                  org_id: @org_id,
                  project_id: @project_id,
                  permission_names: "permission2"
                }
              ]}
           end
         ]},
        {@store_backend, [],
         [
           delete: fn @user_permissions_store_name, _ -> {:ok, ""} end
         ]}
      ] do
        UserPermissions.remove_permissions(RBI.new(project_id: @project_id))

        assert_called_exactly(
          @store_backend.delete(@user_permissions_store_name, [cache_key_1, cache_key_2]),
          1
        )
      end
    end
  end

  describe "recalculate_entire_cache/1" do
    test "with two batches of size 10" do
      user_permission1 = %{
        user_id: @user_id,
        org_id: @org_id,
        permission_names: "permission1"
      }

      user_permission2 = %{
        user_id: @user2_id,
        org_id: @org_id,
        permission_names: "permission2"
      }

      cache_key1 = "user:#{@user_id}_org:#{@org_id}_project:*"
      cache_key2 = "user:#{@user2_id}_org:#{@org_id}_project:*"

      first_batch = :lists.concat(List.duplicate([user_permission1], 10))
      second_batch = :lists.concat(List.duplicate([user_permission2], 6))

      first_batch_keys = :lists.concat(List.duplicate([cache_key1], 10))
      second_batch_keys = :lists.concat(List.duplicate([cache_key2], 6))
      first_batch_values = :lists.concat(List.duplicate(["permission1"], 10))
      second_batch_values = :lists.concat(List.duplicate(["permission2"], 6))

      with_mocks [
        {ComputePermissions, [],
         [
           compute_all_permissions: fn _ ->
             first_batch ++ second_batch
           end
         ]},
        {@store_backend, [],
         [
           put_batch: fn @user_permissions_store_name, keys, _values, _opts ->
             {:ok, length(keys)}
           end,
           clear: fn @user_permissions_store_name -> {:ok, "OK"} end
         ]}
      ] do
        UserPermissions.recalculate_entire_cache(10)

        assert_called_exactly(
          @store_backend.put_batch(
            @user_permissions_store_name,
            first_batch_keys,
            first_batch_values,
            timeout: 60_000
          ),
          1
        )

        assert_called_exactly(
          @store_backend.put_batch(
            @user_permissions_store_name,
            second_batch_keys,
            second_batch_values,
            timeout: 60_000
          ),
          1
        )

        assert_called_exactly(@store_backend.clear(@user_permissions_store_name), 1)
      end
    end
  end
end
