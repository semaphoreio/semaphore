defmodule Support.ApiTestHelpers do
  @moduledoc """
  Shared helper functions for API integration tests.
  """

  @port 4003
  @host "http://localhost:#{@port}"

  @doc """
  Sends a login request to the Guard API.

  ## Parameters

    * `params` - Keyword list with optional keys:
      * `:path` - The path to request (default: "/login")
      * `:query` - Query parameters as a map
      * `:headers` - Additional headers as a list of tuples

  ## Examples

      send_login_request(path: "/oidc/login")
      send_login_request(path: "/oidc/callback", headers: [{"cookie", cookie}], query: %{state: state})

  """
  def send_login_request(params \\ []) do
    query_string = parse_query_params(params[:query])
    path = params[:path] || "/login"

    headers =
      (params[:headers] || []) ++ [{"x-forwarded-proto", "https"}, {"user-agent", "test-agent"}]

    "#{@host}/#{path}#{query_string}"
    |> URI.encode()
    # `pool: false` disables hackney's connection pool. With the pool enabled,
    # hackney does not return the response body of 3xx redirects served over a
    # keep-alive connection (the body is left in the pooled socket), which makes
    # assertions on redirect bodies see an empty string. A fresh connection per
    # request avoids that.
    |> HTTPoison.get(headers, hackney: [pool: false])
  end

  defp parse_query_params(nil), do: ""
  defp parse_query_params(params), do: "?#{URI.encode_query(params)}"
end
