defmodule Guard.InstanceConfig.Api.CookieOrgUsername do
  use Plug.Builder
  import Guard.InstanceConfig.Api.Utils
  require Logger

  def init(opts), do: opts

  def call(conn, opts) do
    with conn <- Plug.Conn.fetch_cookies(conn),
         {:ok, token} <- Map.fetch(conn.cookies, opts[:state_cookie_key]),
         {:ok, %{"org_id" => org_id}} <- Guard.InstanceConfig.Token.decode(token),
         org <- Guard.Api.Organization.fetch(org_id),
         org_username <- org.org_username do
      merge_assigns(conn, org_username: org_username, org_id: org_id)
    else
      :error ->
        Logger.error("Cookie does not contain #{opts[:state_cookie_key]}")

        conn
        |> put_notification(:alert, "Cookie does not contain #{opts[:state_cookie_key]}")
        |> redirect_to_front("")
        |> halt()

      {:error, message} ->
        Logger.error("Error fetching the organization username: #{inspect(message)}")

        conn
        |> put_notification(:alert, message)
        |> redirect_to_front("")
        |> halt()

      {:error, :not_found, conn} ->
        Logger.error("not found Error fetching the organization username:")

        conn
        |> put_notification(:alert, "Error fetching the organization username")
        |> redirect_to_front("")
        |> halt()

      {:ok, err} ->
        Logger.error("no org id Error fetching the organization username: #{inspect(err)}")

        conn
        |> put_notification(:alert, "Cookie does not contain required data")
        |> redirect_to_front("")
        |> halt()
    end
  end
end
