defmodule Google.Rpc.Status do
  @moduledoc false

  use Protobuf,
    full_name: "google.rpc.Status",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:code, 1, type: :int32)
  field(:message, 2, type: :string)
  field(:details, 3, repeated: true, type: Google.Protobuf.Any)
end
