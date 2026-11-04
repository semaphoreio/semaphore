defmodule Audit.Cache do
  alias Audit.Cache

  def fetch(key, cb, opts \\ []) do
    Cachex.fetch(Cache, key, cb, opts)
  end

  def expire(key, ttl) do
    Cachex.expire(Cache, key, ttl)
  end

  def delete(key) do
    Cachex.del(Cache, key)
  end
end
