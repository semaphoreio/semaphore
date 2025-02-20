defmodule Audit.GrpcEncryptor do
  require Logger
  @behaviour Audit.Encryptor

  alias InternalApi.Encryptor.{
    EncryptRequest,
    DecryptRequest
  }

  @impl true
  def encrypt(raw, associated_data, opts) do
    Watchman.benchmark("audit.encryption", fn ->
      with {:ok, url} <- fetch_url(opts),
           {:ok, channel} <- GRPC.Stub.connect(url),
           request <- EncryptRequest.new(raw: raw, associated_data: associated_data),
           {:ok, response} <-
             InternalApi.Encryptor.Encryptor.Stub.encrypt(channel, request, timeout: 5_000) do
        {:ok, response.cypher}
      else
        e ->
          Watchman.increment("audit.encryption.failure")
          Logger.error("Failed to encrypt: #{inspect(e)}")
          {:error, e}
      end
    end)
  end

  @impl true
  def decrypt(cypher, associated_data, opts) do
    Watchman.benchmark("audit.decryption", fn ->
      with {:ok, url} <- fetch_url(opts),
           {:ok, channel} <- GRPC.Stub.connect(url),
           request <- DecryptRequest.new(cypher: cypher, associated_data: associated_data),
           {:ok, response} <-
             InternalApi.Encryptor.Encryptor.Stub.decrypt(channel, request, timeout: 5_000) do
        {:ok, response.raw}
      else
        e ->
          Watchman.increment("audit.decryption.failure")
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
