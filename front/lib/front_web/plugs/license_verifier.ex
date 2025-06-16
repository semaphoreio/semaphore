defmodule FrontWeb.Plugs.LicenseVerifier do
  @moduledoc """
  Plug to verify license status and store it in conn assigns
  """

  import Plug.Conn
  alias Front.Clients.License

  def init(opts), do: opts

  def call(conn, _opts) do
    if Front.ee?() do
      license_status =
        case License.verify_license() do
          {:ok, response} ->
            %{
              valid: response.valid,
              message: response.message,
              expires_at: response.expires_at
            }

          {:error, _reason} ->
            %{
              valid: false,
              message: "Failed to verify license.",
              expires_at: nil
            }
        end

      assign(conn, :license_status, license_status)
    else
      conn
    end
  end
end
