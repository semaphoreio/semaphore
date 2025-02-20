defmodule Google.Protobuf.Any do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :type_url, 1, type: :string, json_name: "typeUrl"
  field :value, 2, type: :bytes
end