defmodule Guard.FailingEncryptor do
  @moduledoc """
  This is a Failing encryptor used for testing purposes. Never use this in production. This is not secure.
  """
  @behaviour Guard.Encryptor

  @impl true
  def encrypt(_, _associated_data, _opts) do
    {:error, "Failed to encrypt"}
  end

  @impl true
  def decrypt(_cypher_text, _associated_data, _opts) do
    {:error, "Failed to decrypt"}
  end
end
