defmodule Google.Protobuf.Any do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.12.0", syntax: :proto3

  field(:type_url, 1, type: :string, json_name: "typeUrl")
  field(:value, 2, type: :bytes)
end
