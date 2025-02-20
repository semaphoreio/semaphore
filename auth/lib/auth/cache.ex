defmodule Auth.Cache do
  @moduledoc false

  require Logger

  def fetch!(key, timeout, callback) do
    case Cachex.fetch(:grpc_api_cache, key, callback) do
      # from cache
      {:ok, value} ->
        value

      # from fallback
      {:commit, value} ->
        Cachex.expire(:grpc_api_cache, key, timeout)
        value

      e ->
        e
    end
  end
end
