defmodule InternalApi.Scouter.SignalRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          context: InternalApi.Scouter.Context.t(),
          event_id: String.t()
        }
  defstruct [:context, :event_id]

  field(:context, 1, type: InternalApi.Scouter.Context)
  field(:event_id, 2, type: :string)
end

defmodule InternalApi.Scouter.SignalResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          event: InternalApi.Scouter.Event.t()
        }
  defstruct [:event]

  field(:event, 1, type: InternalApi.Scouter.Event)
end

defmodule InternalApi.Scouter.ListEventsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          context: InternalApi.Scouter.Context.t(),
          event_ids: [String.t()]
        }
  defstruct [:context, :event_ids]

  field(:context, 1, type: InternalApi.Scouter.Context)
  field(:event_ids, 2, repeated: true, type: :string)
end

defmodule InternalApi.Scouter.ListEventsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          events: [InternalApi.Scouter.Event.t()]
        }
  defstruct [:events]

  field(:events, 1, repeated: true, type: InternalApi.Scouter.Event)
end

defmodule InternalApi.Scouter.Context do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          user_id: String.t(),
          project_id: String.t()
        }
  defstruct [:organization_id, :user_id, :project_id]

  field(:organization_id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:project_id, 3, type: :string)
end

defmodule InternalApi.Scouter.Event do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          context: InternalApi.Scouter.Context.t(),
          occured_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:id, :context, :occured_at]

  field(:id, 1, type: :string)
  field(:context, 2, type: InternalApi.Scouter.Context)
  field(:occured_at, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Scouter.ScouterService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Scouter.ScouterService"

  rpc(:Signal, InternalApi.Scouter.SignalRequest, InternalApi.Scouter.SignalResponse)
  rpc(:ListEvents, InternalApi.Scouter.ListEventsRequest, InternalApi.Scouter.ListEventsResponse)
end

defmodule InternalApi.Scouter.ScouterService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Scouter.ScouterService.Service
end
