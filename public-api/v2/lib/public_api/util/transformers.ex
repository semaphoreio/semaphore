defmodule PublicAPI.Util.Transformers do
  @moduledoc """
  Used to transform timestamps and enums from proto.
  Provide transform_fields with the proto, function to use,
  and fields to transform.
  """

  def transform_fields(proto, func_name, fields \\ []) do
    fields
    |> Enum.reduce(proto, &maybe_transform(&1, &2, func_name))
  end

  defp maybe_transform(key, proto, func_name) do
    if Map.has_key?(proto, key) do
      Map.update(proto, key, nil, &apply(__MODULE__, func_name, [&1]))
    else
      proto
    end
  end

  def timestamps(t) do
    PublicAPI.Util.Timestamps.to_timestamp(t)
  end

  def enums(enum) do
    to_str(enum)
  end

  defp to_str(val) when is_atom(val), do: Atom.to_string(val)
  defp to_str(val) when is_binary(val), do: val

  def from_enums(enum) do
    to_atom(enum)
  end

  defp to_atom(val) when is_binary(val), do: String.to_existing_atom(val)
  defp to_atom(val), do: val

  def from_timestamps(""), do: %Google.Protobuf.Timestamp{seconds: 0, nanos: 0}

  def from_timestamps(timestamp) do
    PublicAPI.Util.Timestamps.to_google_protobuf(timestamp)
  end
end
