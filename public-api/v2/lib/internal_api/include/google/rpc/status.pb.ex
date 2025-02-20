defmodule Google.Rpc.Status do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:code, 1, type: :int32)
  field(:message, 2, type: :string)
  field(:details, 3, repeated: true, type: Google.Protobuf.Any)
end
