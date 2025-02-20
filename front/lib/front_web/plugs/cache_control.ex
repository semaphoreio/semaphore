defmodule FrontWeb.Plugs.CacheControl do
  @moduledoc """
  This plug controls value of the cache-control response header.
  This header is used to prevent browser from caching the response.
  It supports two modes:

  * :no_cache - the response is not cached at all. This should be used for endpoints that return confidential data.
  * :private_cache - the response is cached for a private sessions only and needs to be revalidated for each request
  """

  require Logger

  @type option :: :no_cache | :private_cache

  @spec init(option()) :: option()
  def init(option), do: option

  @spec call(Plug.Conn.t(), option()) :: Plug.Conn.t()
  def call(conn, option) do
    option
    |> case do
      :no_cache ->
        conn
        |> Plug.Conn.put_resp_header(
          "cache-control",
          "no-cache, no-store"
        )

      :private_cache ->
        Plug.Conn.put_resp_header(
          conn,
          "cache-control",
          "no-cache, private, must-revalidate"
        )

      conn ->
        Logger.warn("Invalid #{__MODULE__} header option: #{inspect(option)}")

        conn
    end
  end
end
