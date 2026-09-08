defmodule Zebra.Cache do
  require Logger

  def fetch!(key, timeout, callback) when is_integer(timeout) do
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

  defp with_ttl(result = {:error, _reason}, _timeout), do: result

  defp with_ttl(result = {:ignore, _value}, _timeout), do: result

  defp with_ttl({:commit, value}, timeout), do: {:commit, value, ttl: timeout}

  defp with_ttl({:commit, value, options}, timeout),
    do: {:commit, value, Keyword.put_new(options, :ttl, timeout)}

  defp with_ttl(value, timeout), do: {:commit, value, ttl: timeout}
end
