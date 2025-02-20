defmodule Google.Protobuf.Timestamp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          seconds: integer,
          nanos: integer
        }

  defstruct seconds: 0,
            nanos: 0

  field :seconds, 1, type: :int64
  field :nanos, 2, type: :int32
end
