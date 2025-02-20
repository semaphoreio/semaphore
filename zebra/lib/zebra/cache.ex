defmodule Zebra.Cache do
  require Logger

  def fetch!(key, timeout, callback) do
    case Cachex.fetch(:zebra_cache, key, callback) do
      # from cache
      {:ok, value} ->
        value

      # from fallback
      {:commit, value} ->
        Cachex.expire(:zebra_cache, key, timeout)
        value

      # from fallback
      {:ignore, value} ->
        value

      e ->
        e
    end
  end
end
