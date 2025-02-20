defmodule Google.Protobuf.Timestamp do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.10.0", syntax: :proto3

  field :seconds, 1, type: :int64
  field :nanos, 2, type: :int32
end
