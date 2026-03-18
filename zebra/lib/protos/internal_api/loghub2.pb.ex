defmodule InternalApi.Loghub2.GenerateTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          type: integer,
          duration: non_neg_integer
        }
  defstruct [:job_id, :type, :duration]

  field(:job_id, 1, type: :string)
  field(:type, 2, type: InternalApi.Loghub2.TokenType, enum: true)
  field(:duration, 3, type: :uint32)
end

defmodule InternalApi.Loghub2.GenerateTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          token: String.t(),
          type: integer
        }
  defstruct [:token, :type]

  field(:token, 1, type: :string)
  field(:type, 2, type: InternalApi.Loghub2.TokenType, enum: true)
end

defmodule InternalApi.Loghub2.TokenType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PULL, 0)
  field(:PUSH, 1)
end

defmodule InternalApi.Loghub2.Loghub2.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Loghub2.Loghub2"

  rpc(
    :GenerateToken,
    InternalApi.Loghub2.GenerateTokenRequest,
    InternalApi.Loghub2.GenerateTokenResponse
  )
end

defmodule InternalApi.Loghub2.Loghub2.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Loghub2.Loghub2.Service
end
