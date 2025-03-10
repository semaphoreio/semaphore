defmodule InternalApi.Scouter.SignalRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:context, 1, type: InternalApi.Scouter.Context)
  field(:event_id, 2, type: :string, json_name: "eventId")
end

defmodule InternalApi.Scouter.SignalResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:event, 1, type: InternalApi.Scouter.Event)
end

defmodule InternalApi.Scouter.ListEventsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:context, 1, type: InternalApi.Scouter.Context)
  field(:event_ids, 2, repeated: true, type: :string, json_name: "eventIds")
end

defmodule InternalApi.Scouter.ListEventsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:events, 1, repeated: true, type: InternalApi.Scouter.Event)
end

defmodule InternalApi.Scouter.Context do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:user_id, 2, type: :string, json_name: "userId")
  field(:project_id, 3, type: :string, json_name: "projectId")
end

defmodule InternalApi.Scouter.Event do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:context, 2, type: InternalApi.Scouter.Context)
  field(:occured_at, 3, type: Google.Protobuf.Timestamp, json_name: "occuredAt")
end

defmodule InternalApi.Scouter.ScouterService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Scouter.ScouterService",
    protoc_gen_elixir_version: "0.13.0"

  rpc(:Signal, InternalApi.Scouter.SignalRequest, InternalApi.Scouter.SignalResponse)

  rpc(:ListEvents, InternalApi.Scouter.ListEventsRequest, InternalApi.Scouter.ListEventsResponse)
end

defmodule InternalApi.Scouter.ScouterService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Scouter.ScouterService.Service
end
