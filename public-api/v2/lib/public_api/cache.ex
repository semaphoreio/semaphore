defmodule PublicAPI.Cache do
  @moduledoc false

  require Logger

  def get(key) do
    case Cacheman.get(:public_api, key) do
      {:ok, nil} -> {:not_cached, key}
      {:ok, v} -> {:ok, v}
    end
  end

  def set(key, value) do
    Cacheman.put(:public_api, key, value)
  end

  def set(key, value, timeout) do
    Cacheman.put(:public_api, key, value, ttl: timeout)
  end

  def unset(key) do
    Cacheman.delete(:public_api, key)
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

  def fetch(key, timeout, _default \\ "", callback) do
    Cacheman.fetch(:public_api, key, [ttl: timeout], callback)
  end

  def fetch!(key, timeout, _default \\ "", callback) do
    case Cacheman.fetch(:public_api, key, [ttl: timeout], callback) do
      {:ok, val} -> val
      e -> e
    end
  end

  def encode(data), do: :erlang.term_to_binary(data)
  def decode(data), do: Plug.Crypto.non_executable_binary_to_term(data, [:safe])
end
