defmodule PipelinesAPI.Util.Map do
  @moduledoc false

  def get(map, key, default \\ nil)

  def get(map, key, default) when is_map(map) and is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        value

      :error ->
        get_by_atom_key(map, key, default)
    end
  end

  def get(map, key, default) when is_map(map) and is_atom(key) do
    Map.get(map, key, default)
  end

  def get(_map, _key, default), do: default

  defp get_by_atom_key(map, key, default) do
    Enum.find_value(map, default, &value_for_atom_key(&1, key))
  end

  defp value_for_atom_key({map_key, value}, key) when is_atom(map_key) do
    case Atom.to_string(map_key) do
      ^key -> value
      _ -> nil
    end
  end

  defp value_for_atom_key(_entry, _key), do: nil
end
