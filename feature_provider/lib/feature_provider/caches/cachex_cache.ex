defmodule FeatureProvider.CachexCache do
  use FeatureProvider.Cache

  require Logger
  import FeatureProvider.Util

  alias FeatureProvider.CircuitBreaker

  @default_ttl_ms :timer.minutes(15)
  @default_soft_ttl_ms 0
  @default_stale_ttl_ms 0

  @typedoc """
  - `ttl_ms` - time to live in milliseconds. Defaults to `#{@default_ttl_ms}`
  - `stale_ttl_ms` - how long after `ttl_ms` the last known value is kept to be
    served when a reload fails. A positive integer enables it; anything else
    disables it. Defaults to `#{@default_stale_ttl_ms}` (disabled)
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
  - `breaker` - name of a running `FeatureProvider.CircuitBreaker`. Defaults to `nil` (no breaker)
  """
  @type fetch_opts :: [
          ttl_ms: non_neg_integer(),
          stale_ttl_ms: non_neg_integer(),
          breaker: FeatureProvider.CircuitBreaker.name() | nil,
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
  - `stale_ttl_ms` - when set, a failed callback returns the last known value
    instead of `:not_found`, for up to `ttl_ms + stale_ttl_ms` after it was
    stored. The callback fails when it returns `{:error, _}` (or `:error`),
    raises, exits or throws. Defaults to `#{@default_stale_ttl_ms}` (disabled)
  - `breaker` - name of a running `FeatureProvider.CircuitBreaker`. It opens
    after the callback returns `{:error, :unavailable}` or
    `{:error, {:unavailable, reason}}` a few times in a row. While it is open,
    the callback is not executed (even with `reload`) and the last known value,
    or `:not_found`, is returned. Defaults to `nil` (no breaker)


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

    put = fn default -> load_or_fallback(key, callback, default, opts) end

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

  defp load_or_fallback(key, callback, default, opts) do
    breaker = Keyword.get(opts, :breaker)

    if breaker && CircuitBreaker.open?(breaker) do
      case last_known(key, opts) do
        :not_found -> default
        value -> value
      end
    else
      result = load(key, callback, opts)
      if breaker, do: record(breaker, result, fn -> load(key, callback, opts) end)

      case result do
        {:ok, value} -> value
        failure -> last_known_or_default(key, failure, default, opts)
      end
    end
  end

  defp record(breaker, result, probe) do
    if CircuitBreaker.unavailable?(result),
      do: CircuitBreaker.record_unavailable(breaker, probe),
      else: CircuitBreaker.record_available(breaker)
  end

  # Turns a raising, exiting or throwing callback into a failure, so it can be
  # counted by the breaker and replaced by the last known value. `set/3` returns
  # the callback's result as is, so a bare value is wrapped into `{:ok, value}`.
  defp load(key, callback, opts) do
    key |> set(callback, opts) |> wrap()
  catch
    kind, reason -> {:caught, kind, reason, __STACKTRACE__}
  end

  defp last_known_or_default(key, failure, default, opts) do
    case {last_known(key, opts), failure} do
      # Nothing can stand in for it, so it propagates as before.
      {:not_found, {:caught, kind, reason, stacktrace}} ->
        :erlang.raise(kind, reason, stacktrace)

      {:not_found, _} ->
        default

      {value, _} ->
        Logger.warning(
          "[FeatureProvider.CachexCache] serving last known value for #{inspect(key)}: #{format_failure(failure)}"
        )

        value
    end
  end

  defp format_failure({:caught, kind, reason, stacktrace}), do: Exception.format(kind, reason, stacktrace)
  defp format_failure(error), do: inspect(error)

  defp put_last_known(key, value, opts) do
    case stale_ttl_ms(opts) do
      0 ->
        :ok

      stale_ttl_ms ->
        ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
        {:ok, _} = Cachex.put(Keyword.get(opts, :name), last_known_key(key), value, ttl: ttl_ms + stale_ttl_ms)
    end
  end

  defp last_known(key, opts) do
    case stale_ttl_ms(opts) do
      0 -> :not_found
      _ -> get(last_known_key(key), opts)
    end
  end

  defp stale_ttl_ms(opts) do
    case Keyword.get(opts, :stale_ttl_ms, @default_stale_ttl_ms) do
      stale_ttl_ms when is_integer(stale_ttl_ms) and stale_ttl_ms > 0 -> stale_ttl_ms
      _ -> 0
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
