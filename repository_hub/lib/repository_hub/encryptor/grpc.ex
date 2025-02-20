defmodule RepositoryHub.GRPCEncryptor do
  require Logger
  @behaviour RepositoryHub.Encryptor

  alias InternalApi.Encryptor.{
    EncryptRequest,
    DecryptRequest
  }

  @impl true
  def encrypt(raw, associated_data, opts) do
    Watchman.benchmark("repository_hub.encryption", fn ->
      req = %EncryptRequest{
        raw: raw,
        associated_data: associated_data
      }

      with {:ok, url} <- fetch_url(opts),
           {:ok, channel} <- GRPC.Stub.connect(url),
           {:ok, response} <-
             InternalApi.Encryptor.Encryptor.Stub.encrypt(channel, req, timeout: 5_000),
           _ <- GRPC.Stub.disconnect(channel) do
        {:ok, response.cypher}
      else
        e ->
          Watchman.increment("repository_hub.encryption.failure")
          Logger.error("Failed to encrypt: #{inspect(e)}")
          {:error, e}
      end
    end)
  end

  @impl true
  def decrypt(cypher, associated_data, opts) do
    Watchman.benchmark("repository_hub.decryption", fn ->
      req = %DecryptRequest{
        cypher: cypher,
        associated_data: associated_data
      }

      with {:ok, url} <- fetch_url(opts),
           {:ok, channel} <- GRPC.Stub.connect(url),
           {:ok, response} <-
             InternalApi.Encryptor.Encryptor.Stub.decrypt(channel, req, timeout: 5_000),
           _ <- GRPC.Stub.disconnect(channel) do
        {:ok, response.raw}
      else
        e ->
          Watchman.increment("repository_hub.decryption.failure")
          {:error, e}
      end
    end)
  end

  @spec fetch_url(Keyword.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp fetch_url(opts) do
    opts
    |> Keyword.fetch(:url)
    |> case do
      :error -> {:error, "Missing :url option"}
      {:ok, url} when url == "" -> {:error, ":url cannot be empty"}
      other -> other
    end
  end
end
