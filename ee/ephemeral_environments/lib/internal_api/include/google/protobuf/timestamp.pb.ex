defmodule Google.Protobuf.Timestamp do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:seconds, 1, type: :int64)
  field(:nanos, 2, type: :int32)
end
