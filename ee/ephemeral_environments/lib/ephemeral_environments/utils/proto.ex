defmodule EphemeralEnvironments.Utils.Proto do
  @moduledoc """
  Utility functions for converting between protobuf structs and plain Elixir maps.
  """

  @doc """
  Converts an Elixir map to a protobuf struct of the given module type.
  - Converts DateTime to Google.Protobuf.Timestamp
  - Converts normalized enum atoms (:ready) to protobuf enum atoms (:TYPE_STATE_READY)
  - Recursively processes nested maps to nested proto structs

  ## Examples

      from_map(%{name: "test", state: :ready}, InternalApi.EphemeralEnvironments.EphemeralEnvironmentType)
  """
  def from_map(nil, _module), do: nil

  def from_map(map, module) when is_map(map) and is_atom(module) do
    field_props = module.__message_props__().field_props

    # Convert map to struct fields
    fields =
      map
      |> Enum.map(fn {key, value} ->
        # Find field info for this key
        field_info = find_field_info(field_props, key)
        converted_value = convert_value_from_map(value, field_info)
        {key, converted_value}
      end)
      |> Enum.into(%{})

    struct(module, fields)
  end

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

  # Find field info by field name atom
  defp find_field_info(field_props, field_name) do
    field_props
    |> Enum.find(fn {_num, props} -> props.name_atom == field_name end)
    |> case do
      {_num, props} -> props
      nil -> nil
    end
  end

  defp convert_value_from_map(nil, _field_info), do: nil

  defp convert_value_from_map(%DateTime{} = dt, _field_info) do
    %Google.Protobuf.Timestamp{
      seconds: DateTime.to_unix(dt),
      nanos: 0
    }
  end

  @unix_epoch ~N[1970-01-01 00:00:00]
  defp convert_value_from_map(%NaiveDateTime{} = ndt, _field_info) do
    %Google.Protobuf.Timestamp{
      seconds: NaiveDateTime.diff(ndt, @unix_epoch)
    }
  end

  defp convert_value_from_map(value, nil), do: value

  defp convert_value_from_map(values, field_info) when is_list(values) do
    if field_info.embedded? do
      Enum.map(values, fn item ->
        if is_map(item) and not is_struct(item) do
          from_map(item, field_info.type)
        else
          item
        end
      end)
    else
      values
    end
  end

  # Handle nested maps (embedded messages)
  defp convert_value_from_map(value, field_info) when is_map(value) and not is_struct(value) do
    if field_info.embedded? do
      from_map(value, field_info.type)
    else
      value
    end
  end

  # Handle enum atoms - convert normalized atom back to proto enum
  defp convert_value_from_map(value, field_info) when is_atom(value) do
    if field_info.enum? do
      case field_info.type do
        {:enum, enum_module} -> denormalize_enum_name(value, enum_module)
        _ -> value
      end
    else
      value
    end
  end

  defp convert_value_from_map(value, _field_info), do: value

  # Denormalize enum: :ready -> :TYPE_STATE_READY
  defp denormalize_enum_name(normalized_atom, enum_module) do
    prefix = extract_enum_prefix(enum_module)

    normalized_atom
    |> Atom.to_string()
    |> String.upcase()
    |> then(&"#{prefix}_#{&1}")
    |> String.to_atom()
  end
end
