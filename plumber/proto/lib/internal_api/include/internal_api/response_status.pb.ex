defmodule InternalApi.ResponseStatus do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: integer,
          message: String.t()
        }
  defstruct [:code, :message]

  field(:code, 1, type: InternalApi.ResponseStatus.Code, enum: true)
  field(:message, 2, type: :string)
end

defmodule InternalApi.ResponseStatus.Code do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:OK, 0)
  field(:BAD_PARAM, 1)
end
