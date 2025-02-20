defmodule PipelinesAPI.Secrets.Key do
  @moduledoc false

  use Plug.Builder

  alias PipelinesAPI.SecretClient
  alias PipelinesAPI.Util.ToTuple

  plug(:get_key)

  def get_key(conn, _opts) do
    SecretClient.key()
    |> process_key(conn)
  end

  defp process_key({:ok, key}, conn) do
    params = Map.put(conn.params, "key", key)
    conn = Map.put(conn, :params, params)
    conn
  end

  def process_key(%{id: key_id, key: key}) do
    with {:ok, base_decoded_key} <- Base.decode64(key),
         {:ok, rsa_public_key} <- ExPublicKey.RSAPublicKey.decode_der(base_decoded_key) do
      {:ok, {key_id, rsa_public_key}}
    else
      _ -> ToTuple.internal_error("Error processing key map to key pair")
    end
  end

  def process_key(%{"id" => key_id, "key" => key}) do
    process_key(%{id: key_id, key: key})
  end

  def process_key(_value), do: ToTuple.error("invalid key")
end
