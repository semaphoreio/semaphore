defmodule Google.Rpc.Code do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t ::
          integer
          | :OK
          | :CANCELLED
          | :UNKNOWN
          | :INVALID_ARGUMENT
          | :DEADLINE_EXCEEDED
          | :NOT_FOUND
          | :ALREADY_EXISTS
          | :PERMISSION_DENIED
          | :UNAUTHENTICATED
          | :RESOURCE_EXHAUSTED
          | :FAILED_PRECONDITION
          | :ABORTED
          | :OUT_OF_RANGE
          | :UNIMPLEMENTED
          | :INTERNAL
          | :UNAVAILABLE
          | :DATA_LOSS

  field(:OK, 0)

  field(:CANCELLED, 1)

  field(:UNKNOWN, 2)

  field(:INVALID_ARGUMENT, 3)

  field(:DEADLINE_EXCEEDED, 4)

  field(:NOT_FOUND, 5)

  field(:ALREADY_EXISTS, 6)

  field(:PERMISSION_DENIED, 7)

  field(:UNAUTHENTICATED, 16)

  field(:RESOURCE_EXHAUSTED, 8)

  field(:FAILED_PRECONDITION, 9)

  field(:ABORTED, 10)

  field(:OUT_OF_RANGE, 11)

  field(:UNIMPLEMENTED, 12)

  field(:INTERNAL, 13)

  field(:UNAVAILABLE, 14)

  field(:DATA_LOSS, 15)
end
