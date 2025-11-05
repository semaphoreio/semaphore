defmodule Secrethub.OpenIDConnect.KeyManagerTest do
  use Secrethub.DataCase

  alias Secrethub.OpenIDConnect.KeyManager

  describe "starting a manager" do
    test "when the keys path is wrong, it raises an error" do
      config = [name: :test_keys, keys_path: "/non/existing/folder"]

      expected_error_msg = "OpenID Keys path /non/existing/folder does not exists"
      assert_raise RuntimeError, expected_error_msg, fn -> KeyManager.start_link(config) end
    end

    test "when the folder exists, but the keys are garbage, it raises an error" do
      dir = System.tmp_dir!()
      tmp_file = Path.join(dir, "1660038999.pem")
      File.write!(tmp_file, "garbage")

      config = [name: :test_keys, keys_path: dir]

      Process.flag(:trap_exit, true)
      expected_error_msg = "Failed to load PEM key from #{dir}/1660038999.pem."

      assert {:error, err} = KeyManager.start_link(config)
      assert elem(err, 0) == %RuntimeError{message: expected_error_msg}
    end

    test "when the folder is correctly configured, it starts up without errors" do
      config = [name: :test_keys, keys_path: "priv/openid_keys_in_tests"]

      assert {:ok, _pid} = KeyManager.start_link(config)

      active_key = KeyManager.active_key(:test_keys)

      assert active_key.timestamp == 1_660_042_431
    end

    test "when the folder contains non pem files and directories, it filters them out" do
      #
      # Recreating the sitution I've faced while mounting the files
      # to a kubernetes volume.
      #
      # 1. create a new temporary directory to hold pem files
      dir =
        System.tmp_dir!()
        |> Path.join("oidc_keys_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      # 2. add some actual pem files
      File.ls!("priv/openid_keys_in_tests")
      |> Enum.each(fn f ->
        File.cp(Path.join("priv/openid_keys_in_tests", f), Path.join(dir, f))
      end)

      # 2. Create a subfolder
      File.mkdir!(Path.join(dir, "..2020-12301231"))

      # 3. Create a symbolic link called '..data' to that direcory
      File.ln_s!(Path.join(dir, "..2020-12301231"), Path.join(dir, "..data"))

      # 4. Assert that the symbolic link is not breaking the boot process
      config = [name: :test_keys, keys_path: dir]

      assert {:ok, _} = KeyManager.start_link(config)
      active_key = KeyManager.active_key(:test_keys)

      assert active_key.timestamp == 1_660_042_431
    end
  end

  describe "key manager with key rotation" do
    setup do
      Application.put_env(:secrethub, :openid_keys_cache_max_age_in_s, 1)
      Application.put_env(:secrethub, :on_prem?, true)

      current_time_in_seconds = DateTime.utc_now() |> DateTime.to_unix()
      add_new_key(current_time_in_seconds)

      on_exit(fn ->
        Application.put_env(:secrethub, :openid_keys_cache_max_age_in_s, 0)
        Application.put_env(:secrethub, :on_prem?, false)

        remove_new_key(current_time_in_seconds)
      end)

      %{current_time: current_time_in_seconds}
    end

    test "when the folder contains rotated key, the key becomes active in the specific moment in the future",
         %{current_time: current_time} do
      config = [name: :test_keys, keys_path: "priv/openid_keys_in_tests"]

      assert {:ok, _pid} = KeyManager.start_link(config)

      active_key = KeyManager.active_key(:test_keys)

      # old key is still the active
      assert active_key.timestamp == 1_660_042_431

      # should sleep at least 3*openid_keys_cache_max_age_in_s seconds
      :timer.sleep(5000)

      active_key = KeyManager.active_key(:test_keys)

      # rotated key is now active
      assert active_key.timestamp == current_time
    end

    test "when the folder contains only the old key, the old key is returned in the list of public keys",
         %{current_time: current_time} do
      remove_new_key(current_time)

      config = [name: :test_keys, keys_path: "priv/openid_keys_in_tests"]

      assert {:ok, _pid} = KeyManager.start_link(config)

      pub_keys = KeyManager.public_keys(:test_keys)

      assert length(pub_keys) == 1
      # ID of the old key 1660042431
      assert hd(pub_keys)["kid"] == "2d936e39fb900db1081ef8c5bb6dd708"
    end

    test "when the folder contains rotated key, the old key is not returned in the list of public keys" do
      config = [name: :test_keys, keys_path: "priv/openid_keys_in_tests"]

      assert {:ok, _pid} = KeyManager.start_link(config)

      # should sleep at least 3*openid_keys_cache_max_age_in_s seconds
      :timer.sleep(5000)

      pub_keys = KeyManager.public_keys(:test_keys)

      assert length(pub_keys) == 1
      # ID of the new key which is a copy of the key at templates/key.pem with current timestamp
      assert hd(pub_keys)["kid"] == "d524b07881e4731be5f5a6661dc772cc"
    end

    test "when the folder contains rotated key but also another with recent timestamp, both are returned in the list of public keys",
         %{current_time: current_time} do
      # adds another key with timestamp 1 second in the past
      add_new_key(current_time - 1)
      config = [name: :test_keys, keys_path: "priv/openid_keys_in_tests"]

      assert {:ok, _pid} = KeyManager.start_link(config)
      remove_new_key(current_time - 1)

      :timer.sleep(5000)

      pub_keys = KeyManager.public_keys(:test_keys)

      assert length(pub_keys) == 2
      # ID of the new key which is a copy of the key at templates/key.pem with current timestamp
      assert hd(pub_keys)["kid"] == "d524b07881e4731be5f5a6661dc772cc"
    end
  end

  defp add_new_key(current_time_in_seconds) do
    # create new PEM file with future timestamp
    :ok =
      File.cp(
        "priv/openid_keys_in_tests/templates/key.pem",
        "priv/openid_keys_in_tests/#{current_time_in_seconds}.pem"
      )
  end

  defp remove_new_key(current_time_in_seconds) do
    # remove the new PEM file
    File.rm("priv/openid_keys_in_tests/#{current_time_in_seconds}.pem")
  end
end
