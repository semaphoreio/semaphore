defmodule Secrethub.KeyVaultTest do
  use ExUnit.Case, async: true
  @moduletag capture_log: true

  alias Support.Factories.Model, as: ModelFactory
  alias InternalApi.Secrethub, as: API
  alias Secrethub.KeyVault
  alias Secrethub.KeyVault.Error, as: KeyVaultError

  @keys_path "priv/secret_keys_in_tests"
  @dest_path "/tmp/vault_keys"
  @invalid_key_id 1_666_780_781
  @valid_key_id 1_666_780_782

  setup_all [
    :prepare_data,
    :prepare_encrypted
  ]

  setup [:key_vault_config]

  describe "get_key/0" do
    setup do
      File.mkdir!(@dest_path)
      on_exit(fn -> File.rm_rf!(@dest_path) end)
      {:ok, dest_path: @dest_path}
    end

    test "when config is missing then raises error", _ctx do
      Application.put_env(:secrethub, KeyVault, [])

      assert {:error, %KeyVaultError{kind: :loading, reason: %KeyError{}}} =
               KeyVault.current_key()
    end

    test "when directory is invalid then returns error", _ctx do
      Application.put_env(:secrethub, KeyVault, keys_path: "/tmp/non_existing")

      assert {:error, %KeyVaultError{kind: :loading, reason: %Enum.EmptyError{}}} =
               KeyVault.current_key()
    end

    test "when there are no keys then returns error", ctx do
      Application.put_env(:secrethub, KeyVault, keys_path: ctx.dest_path)

      assert {:error, %KeyVaultError{kind: :loading, reason: %Enum.EmptyError{}}} =
               KeyVault.current_key()
    end

    test "when there are keys and the latest is corrupted then returns error", ctx do
      Application.put_env(:secrethub, KeyVault, keys_path: ctx.dest_path)
      copy_key(ctx.dest_path, @invalid_key_id, @valid_key_id)
      copy_key(ctx.dest_path, @valid_key_id, @invalid_key_id)

      assert {:error, %KeyVaultError{kind: :loading}} = KeyVault.current_key()
    end

    test "when there are keys and the latest is correct then returns it", ctx do
      Application.put_env(:secrethub, KeyVault, keys_path: ctx.dest_path)
      copy_key(ctx.dest_path, @invalid_key_id, @invalid_key_id)
      copy_key(ctx.dest_path, @valid_key_id, @valid_key_id)
      key_id = to_string(@valid_key_id)

      assert {:ok, {^key_id, public_key}} = KeyVault.current_key()
      assert is_binary(public_key)
    end

    test "with default settings returns the test key" do
      key_id = to_string(@valid_key_id)
      assert {:ok, {^key_id, public_key}} = KeyVault.current_key()
      assert is_binary(public_key)
    end
  end

  describe "encrypt/2" do
    test "when config is missing then raises error", ctx do
      Application.put_env(:secrethub, KeyVault, [])

      assert {:error, %KeyVaultError{kind: :loading, reason: %KeyError{}}} =
               KeyVault.encrypt(ctx.raw_data, @valid_key_id)
    end

    test "when directory is invalid then returns error", ctx do
      Application.put_env(:secrethub, KeyVault, keys_path: "/tmp/non_existing")

      assert {:error, %KeyVaultError{kind: :loading, reason: %ExCrypto.Error{reason: :enoent}}} =
               KeyVault.encrypt(ctx.raw_data, @valid_key_id)
    end

    test "when key is missing then returns error", ctx do
      assert {:error, %KeyVaultError{kind: :loading, reason: %ExCrypto.Error{reason: :enoent}}} =
               KeyVault.encrypt(ctx.raw_data, DateTime.utc_now() |> DateTime.to_unix())
    end

    test "when key is valid then returns decrypted value", %{raw_data: raw_data} do
      assert {:ok, encrypted_data} = KeyVault.encrypt(raw_data, @valid_key_id)
      assert {:ok, ^raw_data} = KeyVault.decrypt(encrypted_data)
    end
  end

  describe "decrypt/1" do
    test "when config is missing then raises error", ctx do
      Application.put_env(:secrethub, KeyVault, [])

      assert {:error, %KeyVaultError{kind: :loading, reason: %KeyError{}}} =
               KeyVault.decrypt(ctx.encrypted)
    end

    test "when directory is invalid then returns error", ctx do
      Application.put_env(:secrethub, KeyVault, keys_path: "/tmp/non_existing")

      assert {:error, %KeyVaultError{kind: :loading, reason: %ExCrypto.Error{reason: :enoent}}} =
               KeyVault.decrypt(ctx.encrypted)
    end

    test "when key is missing then returns error", ctx do
      assert {:error, %KeyVaultError{kind: :loading, reason: %ExCrypto.Error{reason: :enoent}}} =
               KeyVault.decrypt(%API.EncryptedData{
                 ctx.encrypted
                 | key_id: DateTime.utc_now() |> DateTime.to_unix()
               })
    end

    test "when key is invalid then returns error", ctx do
      assert {:error,
              %KeyVaultError{
                kind: :decrypt_rsa,
                reason: %ErlangError{original: :decrypt_failed}
              }} = KeyVault.decrypt(%API.EncryptedData{ctx.encrypted | key_id: @invalid_key_id})
    end

    test "when key is valid then returns decrypted value", ctx = %{raw_data: data} do
      assert {:ok, ^data} = KeyVault.decrypt(ctx.encrypted)
    end
  end

  defp key_vault_config(_ctx) do
    Application.put_env(:secrethub, KeyVault, keys_path: @keys_path)

    on_exit(fn ->
      Application.put_env(:secrethub, KeyVault, nil)
    end)
  end

  defp copy_key(dest_path, from_id, to_id) do
    File.copy!(
      Path.join(@keys_path, "#{from_id}.prv.pem"),
      Path.join(dest_path, "#{to_id}.prv.pem")
    )

    File.copy!(
      Path.join(@keys_path, "#{from_id}.pub.pem"),
      Path.join(dest_path, "#{to_id}.pub.pem")
    )
  end

  defp prepare_data(_ctx) do
    secret_data =
      ModelFactory.prepare_content_params()
      |> Map.to_list()
      |> API.Secret.Data.new()

    {:ok, raw_data: secret_data}
  end

  defp prepare_encrypted(ctx) do
    public_key =
      @keys_path
      |> Path.join("#{@valid_key_id}.pub.pem")
      |> ExPublicKey.load!()

    {:ok, aes256_key} = ExCrypto.generate_aes_key(:aes_256, :bytes)

    {:ok, {init_vector, encrypted_payload}} =
      ExCrypto.encrypt(aes256_key, API.Secret.Data.encode(ctx.raw_data))

    {:ok, encoded_aes256_key} = ExPublicKey.encrypt_public(aes256_key, public_key)
    {:ok, encoded_init_vector} = ExPublicKey.encrypt_public(init_vector, public_key)
    encoded_payload = Base.encode64(encrypted_payload)

    {:ok,
     encrypted: %API.EncryptedData{
       key_id: @valid_key_id,
       aes256_key: encoded_aes256_key,
       init_vector: encoded_init_vector,
       payload: encoded_payload
     }}
  end
end
