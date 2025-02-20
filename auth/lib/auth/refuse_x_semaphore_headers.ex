defmodule Auth.RefuseXSemaphoreHeaders do
  import Plug.Conn
  require Logger

  #
  # The Auth service is responsible for setting a list of HTTP headers that
  # identify the caller.
  #
  # These headers are:
  #
  #  "x-semaphore-org-id"
  #  "x-semaphore-org-username"
  #  "x-semaphore-user-anonymous"
  #  "x-semaphore-user-id"
  #
  # If a client manually sets these headers, or any other that starts with
  # x-semaphore, we consider the request a malicious that tries to challenge
  # the sovereignty of this service.
  #
  # Calls that already have these headers before entering the Auth servise are
  # rejected with 404.
  #

  def init(options), do: options

  def call(conn, _opts) do
    malicius_header = find_malicious_header(conn.req_headers)

    if malicius_header do
      {name, v} = malicius_header

      Logger.info("A malicious header found! #{name}=#{v}. Halting the request.")

      conn |> send_resp(404, "Not Found") |> halt()
    else
      # no malicious header found, the request can continue

      conn
    end
  end

  defp find_malicious_header(headers) do
    Enum.find(headers, fn {name, _} -> String.starts_with?(name, "x-semaphore") end)
  end
end
