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

    # hackney >= 1.24 consumes and discards the body of redirect responses
    # (301/302/303/307/308) when a connection pool is used, which is HTTPoison's
    # default. These tests assert on the body of OAuth redirect responses, so we
    # disable pooling to keep the redirect body available to the client.
    "#{@host}/#{path}#{query_string}"
    |> URI.encode()
    |> HTTPoison.get(headers, hackney: [pool: false])
  end

  defp parse_query_params(nil), do: ""
  defp parse_query_params(params), do: "?#{URI.encode_query(params)}"
end
