defmodule FeatureProvider.CachexCache do
  use FeatureProvider.Cache

  require Logger
  import FeatureProvider.Util

  @default_ttl_ms :timer.minutes(15)
  @default_soft_ttl_ms 0
  @default_stale_ttl_ms 0

  @typedoc """
  - `ttl_ms` - time to live in milliseconds. Defaults to `#{@default_ttl_ms}`
  - `stale_ttl_ms` - how long after `ttl_ms` the last known value is kept to be
    served when a reload fails. Defaults to `#{@default_stale_ttl_ms}` (disabled)
  """
  @type set_opts :: [
          ttl_ms: non_neg_integer(),
          stale_ttl_ms: non_neg_integer(),
          cache_name: any()
        ]

  @typedoc """
  - `ttl_ms` - time to live in milliseconds. Defaults to `#{@default_ttl_ms}`
  - `use_cache?` - if set to `false`, the cache won't be used. Defaults to `true`
  - `soft_ttl_ms` - soft time to live in milliseconds. Defaults to `#{@default_soft_ttl_ms}`
  - `stale_ttl_ms` - see `t:set_opts/0`
  """
  @type fetch_opts :: [
          ttl_ms: non_neg_integer(),
          stale_ttl_ms: non_neg_integer(),
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
          put_last_known(key, result, opts)
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
  - `stale_ttl_ms` - when set, a failed (or raising) callback returns the last
    known value instead of `:not_found`, for up to `ttl_ms + stale_ttl_ms`
    after it was stored. Defaults to `#{@default_stale_ttl_ms}` (disabled)


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

  With `stale_ttl_ms`, the last known value outlives `ttl_ms` and is served
  while the callback fails:
      iex> fetch(:my_key, "my_value", [ttl_ms: 50, stale_ttl_ms: 1_000, name: :my_cache])
      "my_value"
      iex> Process.sleep(110)
      iex> get(:my_key, name: :my_cache)
      :not_found
      iex> fetch(:my_key, fn -> {:error, "provider down"} end, [ttl_ms: 50, stale_ttl_ms: 1_000, name: :my_cache])
      "my_value"
      iex> fetch(:my_key, fn -> raise "provider down" end, [ttl_ms: 50, stale_ttl_ms: 1_000, name: :my_cache])
      "my_value"
      iex> fetch(:my_key, "my_other_value", [ttl_ms: 50, stale_ttl_ms: 1_000, name: :my_cache])
      "my_other_value"
  """
  @spec fetch(key(), callback() | value(), fetch_opts()) :: value() | :not_found
  def fetch(_, _, opts \\ [])

  def fetch(key, callback, opts) when is_function(callback, 0) do
    reload = Keyword.get(opts, :reload, false)
    invalidate = Keyword.get(opts, :invalidate, false)

    put = fn default ->
      key
      |> load(callback, opts)
      |> case do
        {:ok, value} -> value
        error -> last_known_or_default(key, error, default, opts)
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

  # A raising callback is only turned into an error when a last known value
  # can stand in for it; otherwise the exception propagates as before.
  defp load(key, callback, opts) do
    set(key, callback, opts)
  rescue
    e ->
      if last_known(key, opts) == :not_found do
        reraise e, __STACKTRACE__
      else
        {:error, {:exception, e}}
      end
  end

  defp last_known_or_default(key, error, default, opts) do
    case last_known(key, opts) do
      :not_found ->
        default

      value ->
        Logger.warning("[FeatureProvider.CachexCache] serving last known value for #{inspect(key)}: #{inspect(error)}")

        value
    end
  end

  defp put_last_known(key, value, opts) do
    case Keyword.get(opts, :stale_ttl_ms, @default_stale_ttl_ms) do
      stale_ttl_ms when stale_ttl_ms > 0 ->
        ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
        {:ok, _} = Cachex.put(Keyword.get(opts, :name), last_known_key(key), value, ttl: ttl_ms + stale_ttl_ms)

      _ ->
        :ok
    end
  end

  defp last_known(key, opts) do
    if Keyword.get(opts, :stale_ttl_ms, @default_stale_ttl_ms) > 0 do
      get(last_known_key(key), opts)
    else
      :not_found
    end
  end

  defp last_known_key(key), do: {__MODULE__, :last_known, key}

  @doc """
  Removes a key from the cache.

  The last known value kept for `stale_ttl_ms` is not removed, so a reload
  after an invalidation can still fall back to it. Use `clear/1` to drop it.

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
