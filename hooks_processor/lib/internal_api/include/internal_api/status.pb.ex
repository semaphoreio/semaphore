defmodule InternalApi.Status do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :code, 1, type: Google.Rpc.Code, enum: true
  field :message, 2, type: :string
end