defmodule HooksReceiver.Plugs.LicenseVerifier do
  require Logger

  @moduledoc """
  Plug to verify license status and store it in conn assigns
  """

  import Plug.Conn
  alias HooksReceiver.LicenseClient

  def init(opts), do: opts

  def call(conn, _opts) do
    if HooksReceiver.ee?() do
      verify_license(conn)
    else
      conn
    end
  end

  defp verify_license(conn) do
    client = Application.get_env(:hooks_receiver, :license_client, LicenseClient)

    case client.verify_license() do
      {:ok, response} ->
        if response.valid do
          conn
        else
          invalid_license_response(conn)
        end

      _ ->
        invalid_license_response(conn)
    end
  end

  defp invalid_license_response(conn) do
    Logger.error("License is not valid.")
    send_resp(conn, 403, "License is not valid.") |> halt()
  end
end
