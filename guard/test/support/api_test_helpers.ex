defmodule Support.ApiTestHelpers do
  @moduledoc """
  Shared helper functions for API integration tests.

  These helpers make real loopback HTTP calls (via HTTPoison/hackney) against
  the guard app's own Cowboy listener started for the test run, rather than
  going through Plug.Test. `hackney: [pool: false]` opts every call out of
  hackney's connection pool: with pooling on, hackney 1.24+'s tighter
  connection-release lifecycle (the fix for GHSA-9fm9-hp7p-53mf) can hand back
  a pooled loopback connection whose previous response hasn't fully drained
  yet, which HTTPoison then reads as a bodyless response (status and headers
  present, body hardcoded to `""`, see `HTTPoison.Base.request/6`). A fresh,
  unpooled connection per call sidesteps that race entirely.
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
    |> HTTPoison.get(headers, hackney: [pool: false])
  end

  @doc """
  Sends a JSON POST request to the Guard API (e.g. the CSRF-exempt `/cli/*`
  endpoints).

  ## Parameters

    * `params` - Keyword list with optional keys:
      * `:path` - The path to request (default: "/")
      * `:body` - Map to encode as the JSON request body (default: `%{}`)
      * `:headers` - Additional headers as a list of tuples

  ## Examples

      send_post_request(path: "/cli/device", body: %{})

  """
  def send_post_request(params \\ []) do
    path = params[:path] || "/"
    body = Jason.encode!(params[:body] || %{})

    headers =
      (params[:headers] || []) ++
        [
          {"x-forwarded-proto", "https"},
          {"user-agent", "test-agent"},
          {"content-type", "application/json"}
        ]

    # `path` already carries its own leading "/" (e.g. "/cli/device"); unlike
    # send_login_request/1, we don't add another one here. A doubled leading
    # slash defeats the CSRF-exemption path match for POST (Unplug compares
    # conn.request_path verbatim, unnormalized) even though it's harmless for
    # GET, since Plug.CSRFProtection never checks safe methods.
    "#{@host}#{path}"
    |> URI.encode()
    |> HTTPoison.post(body, headers, hackney: [pool: false])
  end

  defp parse_query_params(nil), do: ""
  defp parse_query_params(params), do: "?#{URI.encode_query(params)}"
end
