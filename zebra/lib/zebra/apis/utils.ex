defmodule Zebra.Apis.Utils do
  def remove_nils_from_keywordlist(keywordlist) do
    keywordlist |> Enum.filter(fn {_, v} -> v != nil end)
  end

  def encode_timestamps(timestamps) do
    timestamps
    |> remove_nils_from_keywordlist()
    |> Enum.map(fn {k, v} -> {k, DateTime.to_unix(v)} end)
    |> Enum.map(fn {k, v} -> {k, Google.Protobuf.Timestamp.new(seconds: v)} end)
  end
end
