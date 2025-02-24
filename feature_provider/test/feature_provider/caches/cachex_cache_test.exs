defmodule FeatureProvider.CachexCacheTest do
  use ExUnit.Case
  doctest FeatureProvider.CachexCache, import: true

  setup do
    {:ok, _} = start_supervised({Cachex, name: :my_cache})
    :ok
  end
end
