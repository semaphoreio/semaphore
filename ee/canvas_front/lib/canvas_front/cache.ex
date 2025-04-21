defmodule CanvasFront.Cache do
  @moduledoc false

  require Logger

  def get(key) do
    case Cachex.get(:canvas_front_cache, key) do
      {:ok, nil} -> {:not_cached, key}
      {:ok, v} -> {:ok, v}
    end
  end

  def set(key, value) do
    Cachex.put(:canvas_front_cache, key, value)
  end

  def set(key, value, timeout) do
    Cachex.put(:canvas_front_cache, key, value, ttl: timeout)
  end

  def unset(key) do
    Cachex.del(:canvas_front_cache, key)
  end

  def get_all(keys) do
    values = Enum.map(keys, fn k -> get(k) end)
    all_found? = Enum.all?(values, fn v -> elem(v, 0) == :ok end)

    if all_found? do
      {:ok, Enum.map(values, fn {:ok, v} -> v end)}
    else
      keys =
        Enum.filter(values, fn v -> elem(v, 0) == :not_cached end)
        |> Enum.map(fn {:not_cached, k} -> k end)

      {:not_cached, keys}
    end
  end

  def fetch!(key, timeout, _default \\ "", callback) do
    case Cachex.fetch(:canvas_front_cache, key, callback, ttl: timeout) do
      {:ok, val} -> val
      e -> e
    end
  end

  def encode(data), do: :erlang.term_to_binary(data)
  def decode(data), do: Plug.Crypto.non_executable_binary_to_term(data, [:safe])
end
