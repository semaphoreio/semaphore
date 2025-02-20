defmodule InternalClients.Common do
  @moduledoc """
  Common functions used by internal clients request formatters.
  """

  def from_params!(params, key) do
    value = from_params(params, key)

    if is_nil(value) do
      raise ArgumentError, "missing #{inspect(key)}"
    else
      value
    end
  end

  def from_params(params, key, default \\ nil)
  def from_params(nil, _, default), do: default

  def from_params(params, key, default) when is_map(params) do
    value_from_atom_key = Map.get(params, key)
    value_from_string_key = Map.get(params, to_string(key))

    if is_boolean(value_from_atom_key) || is_boolean(value_from_string_key) do
      value_from_atom_key || value_from_string_key || false
    else
      value_from_atom_key || value_from_string_key || default
    end
  end
end
