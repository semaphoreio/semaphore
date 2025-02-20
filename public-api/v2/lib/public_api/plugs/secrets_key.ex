defmodule PublicAPI.Plugs.SecretsKey do
  @moduledoc """
  A plug to get the encryption key from the secrethub and add it to the conn.params
  """
  use Plug.Builder

  alias InternalClients.Secrets, as: SecretClient

  @impl true
  def call(conn, _opts) do
    SecretClient.key()
    |> process_key(conn)
  end

  defp process_key({:ok, key}, conn) do
    Plug.Conn.put_private(conn, :secrets_key, key)
  end
end
