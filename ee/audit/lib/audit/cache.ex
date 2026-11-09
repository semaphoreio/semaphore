defmodule Audit.Cache do
  alias Audit.Cache

  def fetch(key, cb, opts \\ []) do
    Cachex.fetch(Cache, key, cb, opts)
  end

  def expire(key, ttl) do
    Cachex.expire(Cache, key, ttl)
  end

  def put(key, value, ttl) do
    Cachex.put(Cache, key, value, ttl: ttl)
  end
end
