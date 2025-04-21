defmodule InternalApi.Status do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :code, 1, type: Google.Rpc.Code, enum: true
  field :message, 2, type: :string
end
