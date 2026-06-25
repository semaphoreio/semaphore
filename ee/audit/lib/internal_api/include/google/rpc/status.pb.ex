defmodule Google.Rpc.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3


  field(:code, 1, type: :int32)
  field(:message, 2, type: :string)
  field(:details, 3, repeated: true, type: Google.Protobuf.Any)
end
