defmodule InternalApi.ResponseStatus.Code do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :OK, 0
  field :BAD_PARAM, 1
end

defmodule InternalApi.ResponseStatus do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :code, 1, type: InternalApi.ResponseStatus.Code, enum: true
  field :message, 2, type: :string
end
