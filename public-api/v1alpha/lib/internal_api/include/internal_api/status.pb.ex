defmodule InternalApi.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: integer,
          message: String.t()
        }
  defstruct [:code, :message]

  field :code, 1, type: Google.Rpc.Code, enum: true
  field :message, 2, type: :string
end
