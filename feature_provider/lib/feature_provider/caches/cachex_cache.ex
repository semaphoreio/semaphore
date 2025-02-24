defmodule FeatureProvider.CachexCache do
  use FeatureProvider.Cache

  require Logger
  import FeatureProvider.Util

  @default_ttl_ms :timer.minutes(15)
  @default_soft_ttl_ms 0

  @typedoc """
  - `ttl_ms` - time to live in milliseconds. Defaults to `#{@default_ttl_ms}`
  """
  @type set_opts :: [
          ttl_ms: non_neg_integer(),
          cache_name: any()
        ]

  @typedoc """
  - `ttl_ms` - time to live in milliseconds. Defaults to `#{@default_ttl_ms}`
  - `use_cache?` - if set to `false`, the cache won't be used. Defaults to `true`
  - `soft_ttl_ms` - soft time to live in milliseconds. Defaults to `#{@default_soft_ttl_ms}`
  """
  @type fetch_opts :: [
          ttl_ms: non_neg_integer(),
          cache_name: any()
        ]

  @type unset_opts :: [
          cache_name: any()
        ]

  @type key :: any()
  @type value :: any()
  @type cache :: atom() | {atom(), Keyword.t()}
  @type callback :: (() -> Util.maybe(value()))

  @doc """
  Gets a value from the cache. Returns `:not_found` if the value is not found.

  ## Examples

      iex> get(:my_value, name: :my_cache)
      :not_found
      iex> set(:my_value, "my_value", name: :my_cache)
      {:ok, "my_value"}
      iex> get(:my_value, name: :my_cache)
      "my_value"

  """
  @spec get(key(), Keyword.t()) :: value() | :not_found
  def get(key, opts \\ []) do
    cache = Keyword.get(opts, :name)

    Cachex.get(cache, key)
    |> case do
      {:ok, nil} ->
        :not_found

      {:ok, value} ->
        value

      e ->
        log_fun(error: e, key: key, cache: cache)

        :not_found
    end
  end

  @doc """
  Set's a value in the cache.

  ## Examples

      iex> get(:my_key, name: :my_cache)
      :not_found
      iex> set(:my_key, "my_value", name: :my_cache)
      iex> get(:my_key, name: :my_cache)
      "my_value"
      iex> set(:my_key, fn -> {:ok, "my_other_value"} end, name: :my_cache)
      iex> get(:my_key, name: :my_cache)
      "my_other_value"
      iex> set(:my_key, fn -> {:error, "something went wrong"} end, name: :my_cache)
      iex> get(:my_key, name: :my_cache)
      "my_other_value"


    One can use `ttl_ms` option to set the time to live for the value in the cache.
      iex> set(:my_key, "my_value", ttl_ms: 50, name: :my_cache)
      {:ok, "my_value"}
      iex> get(:my_key, name: :my_cache)
      "my_value"
      iex> Process.sleep(100)
      iex> get(:my_key, name: :my_cache)
      :not_found
  """
  @spec set(key(), callback() | value(), set_opts()) :: {:ok, value()} | {:error, any()}
  def set(key, callback, opts \\ [])

  def set(key, callback, opts) when is_function(callback, 0) do
    cache = Keyword.get(opts, :name)
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)

    callback.()
    |> case do
      result ->
        unwrap(result, fn result ->
          {:ok, _} = Cachex.put(cache, key, result, ttl: ttl_ms)
        end)

        result
    end
  end

  def set(key, value, opts), do: set(key, fn -> {:ok, value} end, opts)

  @doc """
  Attempts to fetch a value from the cache.

  If the value is not found, the callback is executed and the result is stored in the cache.

  Accepts the following options:
  - `name` - the cache name
  - `reload` - if set to `true`, the callback will be executed and the result will be stored in the cache. Defaults to `false`
  - `invalidate` - if set to `true`, the cache will be invalidated and the callback will not be executed. Defaults to `false`
  - `ttl_ms` - time to live in milliseconds. Defaults to `#{@default_ttl_ms}`


  # Examples
      iex> get(:my_key, name: :my_cache)
      :not_found
      iex> fetch(:my_key, fn -> {:error, "nope"} end, name: :my_cache)
      :not_found
      iex> fetch(:my_key, "my_value", name: :my_cache)
      "my_value"
      iex> fetch(:my_key, "my_other_value", name: :my_cache)
      "my_value"
      iex> fetch(:my_key, "my_other_value", name: :my_cache, reload: true)
      "my_other_value"

      iex> fetch(:my_key, "my_value", [ttl_ms: 50, name: :my_cache])
      "my_value"
      iex> Process.sleep(110)
      iex> get(:my_key, name: :my_cache)
      :not_found

      iex> fetch(:my_key, "my_value", [name: :my_cache])
      "my_value"
      iex> fetch(:my_key, "my_other_value", [name: :my_cache])
      "my_value"
      iex> fetch(:my_key, "my_other_value", [name: :my_cache, invalidate: true])
      "my_value"
      iex> fetch(:my_key, "my_other_value", [name: :my_cache])
      "my_other_value"
  """
  @spec fetch(key(), callback() | value(), fetch_opts()) :: value() | :not_found
  def fetch(_, _, opts \\ [])

  def fetch(key, callback, opts) when is_function(callback, 0) do
    reload = Keyword.get(opts, :reload, false)
    invalidate = Keyword.get(opts, :invalidate, false)

    put = fn default ->
      set(key, callback, opts)
      |> case do
        {:ok, value} -> value
        _ -> default
      end
    end

    cond do
      reload ->
        put.(:not_found)

      invalidate ->
        result = get(key, opts)
        unset(key, opts)

        result

      true ->
        get(key, opts)
        |> case do
          :not_found ->
            put.(:not_found)

          value ->
            value
        end
    end
  end

  def fetch(key, value, opts), do: fetch(key, fn -> {:ok, value} end, opts)

  @doc """
  Removes a key from the cache.

  ## Examples

      iex> unset(:my_key, name: :my_cache)
      :ok
      iex> get(:my_key, name: :my_cache)
      :not_found
      iex> set(:my_key, "my_value", name: :my_cache)
      {:ok, "my_value"}
      iex> get(:my_key, name: :my_cache)
      "my_value"
      iex> unset(:my_key, name: :my_cache)
      :ok
      iex> get(:my_key, name: :my_cache)
      :not_found
  """
  @spec unset(key(), unset_opts()) :: :ok
  def unset(key, opts \\ []) do
    cache = Keyword.get(opts, :name)

    Cachex.del(cache, key)

    :ok
  end

  @doc ~S"""
  Clears the cache.

  ## Examples

      iex> set(:my_key, "my_value", name: :my_cache)
      {:ok, "my_value"}
      iex> set(:my_other_key, "my_other_value", name: :my_cache)
      {:ok, "my_other_value"}
      iex> clear(name: :my_cache)
      :ok
      iex> get(:my_key, name: :my_cache)
      :not_found
      iex> get(:my_other_key, name: :my_cache)
      :not_found
  """
  @spec clear(Keyword.t()) :: :ok
  def clear(opts \\ []) do
    cache = Keyword.get(opts, :name)
    Cachex.clear(cache)

    :ok
  end
end
