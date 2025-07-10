defmodule Google.Rpc.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: integer,
          message: String.t(),
          details: [Google.Protobuf.Any.t()]
        }
  defstruct [:code, :message, :details]

  field(:code, 1, type: :int32)
  field(:message, 2, type: :string)
  field(:details, 3, repeated: true, type: Google.Protobuf.Any)
end
