defmodule Secrethub.Encryptor do
  require Logger

  import Ecto.Query, only: [where: 2]

  alias Secrethub.Repo
  alias Secrethub.Model.Content
  alias Secrethub.Model.EnvVar
  alias Secrethub.Model.File

  alias InternalApi.Encryptor.{
    EncryptRequest,
    DecryptRequest
  }

  def encrypt_changeset(changeset, params, content_field) do
    if changeset.valid? do
      case Secrethub.Encryptor.encrypt(
             Poison.encode!(Map.get(params, content_field)),
             params.name
           ) do
        {:ok, encrypted} ->
          changeset |> Ecto.Changeset.change(content_encrypted: encrypted)

        e ->
          Logger.error("Failed to encrypt '#{params.name}': #{inspect(e)}")
          changeset |> Ecto.Changeset.add_error(:encryption, "failed to encrypt secret contents")
      end
    else
      changeset |> Ecto.Changeset.change(content_encrypted: nil)
    end
  end

  def encrypt(raw, associated_data) do
    Watchman.benchmark("secrethub.encryption", fn ->
      req =
        EncryptRequest.new(
          raw: raw,
          associated_data: associated_data
        )

      with {:ok, channel} <- GRPC.Stub.connect(config!(:url)),
           {:ok, response} <-
             InternalApi.Encryptor.Encryptor.Stub.encrypt(channel, req, timeout: 5_000) do
        {:ok, response.cypher}
      else
        e ->
          Watchman.increment("secrethub.encryption.failure")
          Logger.error("Failed to encrypt: #{inspect(e)}")
          {:error, e}
      end
    end)
  end

  def decrypt_secret(secret) do
    case decrypt(secret.content_encrypted, secret.name) do
      {:ok, decrypted} ->
        {
          :ok,
          %{
            secret
            | content:
                Poison.decode!(
                  decrypted,
                  as: %Content{
                    env_vars: [%EnvVar{}],
                    files: [%File{}]
                  }
                )
          }
        }

      e ->
        Logger.error("Failed to decrypt: #{inspect(e)}")
        {:error, e}
    end
  end

  def encrypt_secret(model, id, name, data) do
    case encrypt(Poison.encode!(data), name) do
      {:ok, encrypted} ->
        model
        |> where(id: ^id)
        |> Repo.update_all(set: [content_encrypted: encrypted])
        |> case do
          {:error, e} ->
            Logger.error("Failed to update '#{name}' with encrypted data: #{inspect(e)}")

          _ ->
            Logger.info("Secret '#{name}' was successfully encrypted.")
        end

      {:error, e} ->
        Logger.error("Failed to encrypt '#{name}': #{inspect(e)}")
    end
  end

  def decrypt(cypher, associated_data) do
    Watchman.benchmark("secrethub.decryption", fn ->
      req =
        DecryptRequest.new(
          cypher: cypher,
          associated_data: associated_data
        )

      with {:ok, channel} <- GRPC.Stub.connect(config!(:url)),
           {:ok, response} <-
             InternalApi.Encryptor.Encryptor.Stub.decrypt(channel, req, timeout: 5_000) do
        {:ok, response.raw}
      else
        e ->
          Watchman.increment("secrethub.decryption.failure")
          {:error, e}
      end
    end)
  end

  defp config, do: Application.get_env(:secrethub, __MODULE__, [])
  defp config!(key), do: config() |> Keyword.fetch!(key)
end
