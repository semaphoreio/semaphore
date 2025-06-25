defmodule Google.Protobuf.Any do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type_url: String.t(),
          value: String.t()
        }
  defstruct [:type_url, :value]

  field :type_url, 1, type: :string
  field :value, 2, type: :bytes
end
