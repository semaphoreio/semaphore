defmodule InternalApi.ResponseStatus.Code do
  @moduledoc false

  use Protobuf,
    enum: true,
    full_name: "InternalApi.ResponseStatus.Code",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:OK, 0)
  field(:BAD_PARAM, 1)
end

defmodule InternalApi.ResponseStatus do
  @moduledoc false

  use Protobuf,
    full_name: "InternalApi.ResponseStatus",
    protoc_gen_elixir_version: "0.17.0",
    syntax: :proto3

  field(:code, 1, type: InternalApi.ResponseStatus.Code, enum: true)
  field(:message, 2, type: :string)
end
