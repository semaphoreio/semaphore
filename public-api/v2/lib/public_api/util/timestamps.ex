defmodule PublicAPI.Util.Timestamps do
  @moduledoc """
  This module can be used to transform timestamps to and from ISO 8601 format.
  """

  def transform_timestamps(proto, fields \\ []) do
    fields
    |> Enum.reduce(proto, fn key, acc ->
      Map.update!(acc, key, fn timestamp -> to_timestamp(timestamp) end)
    end)
  end

  def to_timestamp(nil), do: nil
  def to_timestamp(%Google.Protobuf.Timestamp{nanos: 0, seconds: 0}), do: nil

  def to_timestamp(%Google.Protobuf.Timestamp{nanos: nanos, seconds: seconds}) do
    ts_in_microseconds = seconds * 1_000_000 + Integer.floor_div(nanos, 1_000)
    {:ok, ts_date_time} = DateTime.from_unix(ts_in_microseconds, :microsecond)

    ts_date_time
    |> DateTime.truncate(:millisecond)
    |> DateTime.to_iso8601()
  end

  def to_timestamp(unix_timestamp) when is_integer(unix_timestamp) do
    {:ok, ts_date_time} = DateTime.from_unix(unix_timestamp, :second)
    DateTime.to_iso8601(ts_date_time)
  end

  def to_google_protobuf(nil), do: %Google.Protobuf.Timestamp{seconds: 0, nanos: 0}

  def to_google_protobuf(timestamp = %DateTime{}) do
    ts_in_microseconds = DateTime.to_unix(timestamp, :microsecond)
    seconds = div(ts_in_microseconds, 1_000_000)
    nanos = rem(ts_in_microseconds, 1_000_000) * 1_000
    %Google.Protobuf.Timestamp{seconds: seconds, nanos: nanos}
  end
end
