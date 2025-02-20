defmodule InternalApi.Loghub.GetLogEventsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          starting_line: integer
        }
  defstruct [:job_id, :starting_line]

  field(:job_id, 1, type: :string)
  field(:starting_line, 2, type: :int32)
end

defmodule InternalApi.Loghub.GetLogEventsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          events: [String.t()],
          final: boolean
        }
  defstruct [:status, :events, :final]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:events, 2, repeated: true, type: :string)
  field(:final, 3, type: :bool)
end

defmodule InternalApi.Loghub.Loghub.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Loghub.Loghub"

  rpc(
    :GetLogEvents,
    InternalApi.Loghub.GetLogEventsRequest,
    InternalApi.Loghub.GetLogEventsResponse
  )
end

defmodule InternalApi.Loghub.Loghub.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Loghub.Loghub.Service
end
