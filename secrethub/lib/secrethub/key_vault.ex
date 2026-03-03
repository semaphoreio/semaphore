defmodule Secrethub.KeyVault.Error do
  defexception [:kind, :reason, :key_id]

  def message(exception = %__MODULE__{}), do: "#{inspect(exception)}"

  def external_message(%__MODULE__{kind: :loading, key_id: key_id}),
    do: "Loading key failed: #{inspect(key_id)}"

  def external_message(%__MODULE__{kind: :generate_aes, key_id: key_id}),
    do: "Loading key failed: #{inspect(key_id)}"

  def external_message(%__MODULE__{kind: :decode_base64, key_id: key_id}),
    do: "Base64 decoding payload failed: #{inspect(key_id)}"

  def external_message(%__MODULE__{kind: :encrypt_aes, key_id: key_id}),
    do: "AES encryption error: #{inspect(key_id)}"

  def external_message(%__MODULE__{kind: :decrypt_aes, key_id: key_id}),
    do: "AES decryption error: #{inspect(key_id)}"

  def external_message(%__MODULE__{kind: :encrypt_rsa, key_id: key_id}),
    do: "RSA encryption error: #{inspect(key_id)}"

  def external_message(%__MODULE__{kind: :decrypt_rsa, key_id: key_id}),
    do: "RSA decryption error: #{inspect(key_id)}"
end

defmodule Secrethub.KeyVault do
  alias InternalApi.Secrethub, as: API
  alias Secrethub.KeyVault.Error, as: KeyVaultError
  require Logger

  def current_key do
    with {:ok, key_id} <- max_key_id(),
         {:ok, public_key} <- load_public_key(key_id),
         {:ok, der_public_key} <- encode_der(public_key) do
      {:ok, {to_string(key_id), Base.encode64(der_public_key)}}
    end
  end

  defp encode_der(public_key) do
    case ExPublicKey.RSAPublicKey.encode_der(public_key) do
      {:ok, der_public_key} -> {:ok, der_public_key}
      {:error, reason} -> wrap_error(:loading, reason)
    end
  end

  def encrypt(secret_data = %API.Secret.Data{}, key_id) do
    encoded_payload = API.Secret.Data.encode(secret_data)

    with {:ok, public_key} <- load_public_key(key_id),
         {:ok, aes256_key} <- generate_aes256_key(),
         {:ok, {init_vector, encrypted_payload}} <- encrypt_aes(aes256_key, encoded_payload),
         {:ok, encrypted_aes256_key} <- encrypt_rsa(aes256_key, public_key),
         {:ok, encrypted_init_vector} <- encrypt_rsa(init_vector, public_key) do
      {:ok,
       API.EncryptedData.new(
         key_id: to_string(key_id),
         aes256_key: to_string(encrypted_aes256_key),
         init_vector: to_string(encrypted_init_vector),
         payload: Base.encode64(encrypted_payload)
       )}
    else
      {:error, error = %KeyVaultError{}} ->
        error = %KeyVaultError{error | key_id: key_id}

        error
        |> KeyVaultError.message()
        |> Logger.error()

        {:error, error}
    end
  end

  defp generate_aes256_key do
    case ExCrypto.generate_aes_key(:aes_256, :bytes) do
      {:ok, aes256_key} -> {:ok, aes256_key}
      {:error, reason} -> wrap_error(:generate_aes, reason)
    end
  end

  defp encrypt_aes(aes256_key, text) do
    case ExCrypto.encrypt(aes256_key, text) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> wrap_error(:encrypt_aes, reason)
    end
  end

  defp encrypt_rsa(text, public_key) do
    case ExPublicKey.encrypt_public(text, public_key) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> wrap_error(:encrypt_rsa, reason)
      {:error, reason, _st} -> wrap_error(:encrypt_rsa, reason)
    end
  end

  def decrypt(encrypted = %API.EncryptedData{}) do
    with {:ok, private_key} <- load_private_key(encrypted.key_id),
         {:ok, init_vector} <- decrypt_rsa(encrypted.init_vector, private_key),
         {:ok, aes256_key} <- decrypt_rsa(encrypted.aes256_key, private_key),
         :ok <- validate_aes_material(aes256_key, init_vector),
         {:ok, payload} <- decode_payload(encrypted.payload),
         {:ok, payload} <- decrypt_aes(payload, aes256_key, init_vector) do
      {:ok, API.Secret.Data.decode(payload)}
    else
      {:error, error = %KeyVaultError{}} ->
        error = %KeyVaultError{error | key_id: encrypted.key_id}

        error
        |> KeyVaultError.message()
        |> Logger.error()

        {:error, error}
    end
  end

  defp decode_payload(payload) do
    case Base.decode64(payload) do
      {:ok, payload} -> {:ok, payload}
      :error -> wrap_error(:decode_base64, "decoding failed")
    end
  end

  defp decrypt_aes(payload, aes256_key, init_vector) do
    case ExCrypto.decrypt(aes256_key, init_vector, payload) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason, _stacktrace} ->
        wrap_error(:decrypt_aes, reason)

      {:error, reason} ->
        wrap_error(:decrypt_aes, reason)

      {kind, reason, _stacktrace} when kind in [:error, :exit] ->
        wrap_error(:decrypt_aes, reason)

      unexpected ->
        wrap_error(:decrypt_aes, unexpected)
    end
  end

  defp validate_aes_material(aes256_key, init_vector) do
    cond do
      byte_size(init_vector) != 16 ->
        wrap_error(:decrypt_rsa, %ErlangError{original: :decrypt_failed})

      byte_size(aes256_key) not in [16, 24, 32] ->
        wrap_error(:decrypt_rsa, %ErlangError{original: :decrypt_failed})

      true ->
        :ok
    end
  end

  defp decrypt_rsa(encrypted, private_key) do
    case ExPublicKey.decrypt_private(encrypted, private_key) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> wrap_error(:decrypt_rsa, reason)
      {:error, reason, _st} -> wrap_error(:decrypt_rsa, reason)
    end
  end

  def load_private_key(key_id), do: load_key(key_id, :private)
  def load_public_key(key_id), do: load_key(key_id, :public)

  defp load_key(key_id, type) do
    {:ok, key_id |> key_path(type) |> ExPublicKey.load!()}
  rescue
    e -> wrap_error(:loading, e)
  end

  defp max_key_id do
    {:ok,
     key_path("*", :private)
     |> Path.wildcard()
     |> Stream.map(&path_to_key_id/1)
     |> Enum.max()}
  rescue
    e -> wrap_error(:loading, e)
  end

  defp path_to_key_id(path) do
    Path.basename(path)
    |> String.trim_trailing(".pub.pem")
    |> String.trim_trailing(".prv.pem")
    |> Integer.parse()
    |> case do
      {key_id, _} -> key_id
      :error -> raise "Wrong key filename"
    end
  end

  defp key_path(key_id, type),
    do: Path.join(config!(:keys_path), key_filename(key_id, type))

  defp key_filename(key_id, :private), do: "#{key_id}.prv.pem"
  defp key_filename(key_id, :public), do: "#{key_id}.pub.pem"

  defp config, do: Application.get_env(:secrethub, __MODULE__, [])
  defp config!(key), do: config() |> Keyword.fetch!(key)

  defp wrap_error(kind, reason),
    do: {:error, %KeyVaultError{kind: kind, reason: reason}}
end
