defmodule InternalApi.Loghub.GetLogEventsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
  field(:starting_line, 2, type: :int32, json_name: "startingLine")
end

defmodule InternalApi.Loghub.GetLogEventsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:events, 2, repeated: true, type: :string)
  field(:final, 3, type: :bool)
end

defmodule InternalApi.Loghub.Loghub.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Loghub.Loghub", protoc_gen_elixir_version: "0.13.0"

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
