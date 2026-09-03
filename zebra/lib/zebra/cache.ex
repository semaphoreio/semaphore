defmodule Zebra.Cache do
  require Logger

  def fetch!(key, timeout, callback) do
    case Cachex.fetch(:zebra_cache, key, fn -> with_ttl(callback.(), timeout) end) do
      {:ok, value} ->
        value

      {:commit, value} ->
        value

      {:commit, value, _options} ->
        value

      {:ignore, value} ->
        value

      e ->
        e
    end
  end

  defp with_ttl({:ignore, _value} = result, _timeout), do: result

  defp with_ttl({:commit, value}, timeout), do: {:commit, value, ttl: timeout}

  defp with_ttl({:commit, value, options}, timeout) when is_list(options),
    do: {:commit, value, Keyword.put_new(options, :ttl, timeout)}

  defp with_ttl(value, timeout), do: {:commit, value, ttl: timeout}
end
