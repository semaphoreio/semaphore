defmodule Secrethub.ApplicationTest do
  use ExUnit.Case, async: false

  alias Secrethub.Application, as: App

  describe "openid_key_manager_children/0" do
    setup do
      prev_start = System.get_env("START_OPENID_KEY_MANAGER")
      prev_openid = Application.get_env(:secrethub, :openid_keys_path)
      prev_cache = Application.get_env(:secrethub, :cache_openid_keys_path)

      on_exit(fn ->
        if prev_start,
          do: System.put_env("START_OPENID_KEY_MANAGER", prev_start),
          else: System.delete_env("START_OPENID_KEY_MANAGER")

        Application.put_env(:secrethub, :openid_keys_path, prev_openid)
        Application.put_env(:secrethub, :cache_openid_keys_path, prev_cache)
      end)

      System.put_env("START_OPENID_KEY_MANAGER", "true")
      Application.put_env(:secrethub, :openid_keys_path, "priv/openid_keys_in_tests")
      :ok
    end

    # Regression: both keysets are the same KeyManager module, so without an
    # explicit per-child id they collapse to the module-name id and the
    # supervisor refuses to boot with :duplicate_child_name once the cache
    # keyset is also configured (as it is in staging/prod).
    test "uses distinct child ids when both keysets are configured" do
      Application.put_env(:secrethub, :cache_openid_keys_path, "priv/cache_openid_keys_in_tests")

      ids = Enum.map(App.openid_key_manager_children(), & &1.id)

      assert ids == [:openid_keys, :cache_openid_keys]
      assert Enum.uniq(ids) == ids
    end

    test "starts only the customer keyset when the cache keyset is unconfigured" do
      Application.put_env(:secrethub, :cache_openid_keys_path, nil)

      ids = Enum.map(App.openid_key_manager_children(), & &1.id)

      assert ids == [:openid_keys]
    end
  end
end
