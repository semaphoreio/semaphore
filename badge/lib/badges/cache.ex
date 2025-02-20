defmodule Badges.Cache do
  require Logger

  alias Badges.CacheKey

  def fetch!(key_parts, timeout, callback) when is_list(key_parts) do
    CacheKey.calculate(key_parts) |> fetch!(timeout, callback)
  end

  def fetch!(key, timeout, callback) do
    case Cachex.fetch(:badges_cache, key, callback) do
      # from cache
      {:ok, value} ->
        value

      # from fallback
      {:commit, value} ->
        Cachex.expire(:badges_cache, key, timeout)
        value

      {:ignore, value} ->
        value

      e ->
        Sentry.Context.set_extra_context(%{
          cache: inspect(e),
          key: key,
          timeout: timeout
        })

        e
    end
  end
end
