defmodule InternalApi.ResponseStatus.Code do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:OK, 0)
  field(:BAD_PARAM, 1)
end

defmodule InternalApi.ResponseStatus do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:code, 1, type: InternalApi.ResponseStatus.Code, enum: true)
  field(:message, 2, type: :string)
end
