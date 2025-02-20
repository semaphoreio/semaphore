defmodule Secrethub.EncryptorTest do
  use Secrethub.DataCase, async: true

  alias Secrethub.Encryptor

  setup [:encryptor_config]

  describe ".encrypt/2" do
    test "plain text can be encrypted and decrypted" do
      data = "mydata"
      associated_data = "myassociateddata"
      assert {:ok, cypher} = Encryptor.encrypt(data, associated_data)
      assert cypher != ""

      assert {:ok, plain} = Encryptor.decrypt(cypher, associated_data)
      assert plain == data
    end

    test "JSON can be encrypted and decrypted" do
      secret_content = %{
        env_vars: [
          %{name: "MY_VAR_1", value: "very-secret-value"}
        ],
        files: [
          %{path: "secret.json", content: "very-secret-content"}
        ]
      }

      data = Poison.encode!(secret_content)
      associated_data = "myassociateddata"
      assert {:ok, cypher} = Encryptor.encrypt(data, associated_data)
      assert cypher != ""

      assert {:ok, plain} = Encryptor.decrypt(cypher, associated_data)
      decrypted_secret = Poison.decode!(plain)

      assert decrypted_secret["env_vars"] == [
               %{"name" => "MY_VAR_1", "value" => "very-secret-value"}
             ]

      assert decrypted_secret["files"] == [
               %{"path" => "secret.json", "content" => "very-secret-content"}
             ]
    end
  end

  defp encryptor_config(_ctx) do
    on_exit(fn ->
      Application.put_env(:secrethub, KeyVault, nil)
    end)
  end
end
