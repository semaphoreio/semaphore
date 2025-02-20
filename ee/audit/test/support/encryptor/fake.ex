defmodule Audit.FakeEncryptor do
  @moduledoc """
  This is a Fake encryptor used for testing purposes. Never use this in production. This is not secure.
  """
  @behaviour Audit.Encryptor

  <<key::binary-16, _rest::binary>> = :crypto.hash(:sha256, "super secret")
  @key key

  @impl true
  def encrypt(raw, _associated_data, _opts) do
    iv = :crypto.strong_rand_bytes(16)
    cypher = :crypto.crypto_one_time(:aes_128_ctr, @key, iv, raw, true)
    {:ok, iv <> cypher}
  end

  @impl true
  def decrypt(cypher_text, _associated_data, _opts) do
    <<iv::binary-16, cypher::binary>> = cypher_text
    {:ok, :crypto.crypto_one_time(:aes_128_ctr, @key, iv, cypher, false)}
  end
end
