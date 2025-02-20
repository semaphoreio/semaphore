defmodule RepositoryHub.Encryptor do
  @callback encrypt(raw :: String.t(), associated_data :: String.t(), opts :: Keyword.t()) ::
              {:ok, encrypted_data :: String.t()} | {:error, reason :: any}

  @callback decrypt(cypher :: String.t(), associated_data :: String.t(), opts :: Keyword.t()) ::
              {:ok, decrypted_data :: String.t()} | {:error, reason :: any}

  def encrypt(encryptor, raw, associated_data, opts \\ [])
  def encrypt(_encryptor, "", _associated_data, __opts), do: {:ok, ""}

  def encrypt(encryptor, raw, associated_data, opts) do
    {module, module_opts} = module_with_opts(encryptor)
    opts = Keyword.merge(module_opts, opts)

    module.encrypt(raw, associated_data, opts)
  end

  def encrypt!(encryptor, raw, associated_data, opts \\ []) do
    case encrypt(encryptor, raw, associated_data, opts) do
      {:ok, encrypted_data} -> encrypted_data
      {:error, reason} -> raise "Failed to encrypt: #{inspect(reason)}"
    end
  end

  def decrypt(encryptor, cypher, associated_data, opts \\ [])
  def decrypt(_encryptor, "", _associated_data, _opts), do: {:ok, ""}

  def decrypt(encryptor, cypher, associated_data, opts) do
    {module, module_opts} = module_with_opts(encryptor)
    opts = Keyword.merge(module_opts, opts)

    module.decrypt(cypher, associated_data, opts)
  end

  def decrypt!(encryptor, cypher, associated_data, opts \\ []) do
    case decrypt(encryptor, cypher, associated_data, opts) do
      {:ok, decrypted_data} -> decrypted_data
      {:error, reason} -> raise "Failed to decrypt: #{inspect(reason)}"
    end
  end

  defp module_with_opts(encryptor) do
    Application.get_env(:repository_hub, encryptor)
    |> Keyword.fetch(:module)
    |> case do
      :error -> raise "Missing :module option for #{__MODULE__}"
      {:ok, module} -> module
    end
  end
end
