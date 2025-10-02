defmodule EphemeralEnvironments.Utils.Proto do
  @moduledoc """
  Utility functions for converting protobuf structs to plain Elixir maps.
  """

  @doc """
  Recursively converts a protobuf struct to a plain Elixir map.
  - Converts Google.Protobuf.Timestamp to DateTime
  - Converts enums to their atom names (INSTANCE_STATE_PROVISIONING -> :provisioning)
  - Recursively processes nested structs
  """
  def to_map(nil), do: nil

  def to_map(%Google.Protobuf.Timestamp{} = timestamp) do
    DateTime.from_unix!(timestamp.seconds, :second)
    |> DateTime.add(timestamp.nanos, :nanosecond)
  end

  def to_map(%module{} = struct) when is_atom(module) do
    struct
    |> Map.from_struct()
    |> Enum.map(fn {key, value} -> {key, convert_value(value, module, key)} end)
    |> Map.new()
  end

  def to_map(value), do: value

  defp convert_value(value, module, field) when is_list(value) do
    Enum.map(value, &to_map/1)
  end

  defp convert_value(value, module, field) when is_struct(value) do
    to_map(value)
  end

  defp convert_value(value, module, field) when is_integer(value) do
    # Check if this field is an enum by looking at the field definition
    case get_enum_module(module, field) do
      nil -> value
      enum_module -> integer_to_atom(enum_module, value)
    end
  end

  defp convert_value(value, module, field) when is_atom(value) do
    # Check if this is an enum atom that needs normalization
    case get_enum_module(module, field) do
      nil -> value
      enum_module -> normalize_enum_name(value, enum_module)
    end
  end

  defp convert_value(value, _module, _field), do: value

  # If given field is of type enum inside the parend module, the name of the enum module
  # will be returned. Otherwise it will return nil.
  defp get_enum_module(module, field) do
    try do
      field_props = module.__message_props__().field_props

      # Find the field by name_atom
      field_info =
        field_props
        |> Enum.find(fn {_num, props} -> props.name_atom == field end)
        |> case do
          {_num, props} -> props
          nil -> nil
        end

      if field_info && field_info.enum? do
        case field_info.type do
          {:enum, enum_module} -> enum_module
          _ -> nil
        end
      else
        nil
      end
    rescue
      _ -> nil
    end
  end

  defp integer_to_atom(enum_module, value) do
    try do
      enum_module.__message_props__()
      |> Map.get(:field_props, %{})
      |> Enum.find(fn {_name, props} -> props[:enum_value] == value end)
      |> case do
        {name, _} -> normalize_enum_name(name, enum_module)
        nil -> value
      end
    rescue
      _ -> value
    end
  end

  # Normalize enum names by removing prefix and lowercasing
  # E.g., :INSTANCE_STATE_ZERO_STATE -> :zero_state (for InternalApi.EphemeralEnvironments.InstanceState)
  #       :TYPE_STATE_DRAFT -> :draft (for InternalApi.EphemeralEnvironments.TypeState)
  defp normalize_enum_name(enum_atom, enum_module) do
    prefix = extract_enum_prefix(enum_module)

    enum_atom
    |> Atom.to_string()
    |> String.replace_prefix(prefix <> "_", "")
    |> String.downcase()
    |> String.to_atom()
  end

  # Extract the enum prefix from the module name
  # E.g., InternalApi.EphemeralEnvironments.InstanceState -> "INSTANCE_STATE"
  #       InternalApi.EphemeralEnvironments.StateChangeActionType -> "STATE_CHANGE_ACTION_TYPE"
  defp extract_enum_prefix(enum_module) do
    enum_module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.upcase()
  end
end
