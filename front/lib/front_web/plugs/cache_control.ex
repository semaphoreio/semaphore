defmodule FrontWeb.Plugs.CacheControl do
  @moduledoc """
  This plug controls value of the cache-control response header.
  This header is used to control browser caching behavior.
  It supports three modes:

  * :no_cache - the response is not cached at all. This should be used for endpoints that return confidential data.
  * :private_cache - the response is cached for a private session only and needs to be revalidated for each request
  * :etag_cache - the response is cached privately and can be served from cache after ETag revalidation
  """

  require Logger

  @type option :: :no_cache | :private_cache | :etag_cache

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

      :etag_cache ->
        Plug.Conn.put_resp_header(
          conn,
          "cache-control",
          "private, max-age=0, must-revalidate"
        )

      conn ->
        Logger.warn("Invalid #{__MODULE__} header option: #{inspect(option)}")

        conn
    end
  end
end
