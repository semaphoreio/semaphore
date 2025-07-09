defmodule InternalApi.Stethoscope.EventRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          request_token: String.t(),
          listener: String.t(),
          attributes: %{String.t() => String.t()}
        }
  defstruct [:request_token, :listener, :attributes]

  field(:request_token, 1, type: :string)
  field(:listener, 2, type: :string)

  field(:attributes, 3,
    repeated: true,
    type: InternalApi.Stethoscope.EventRequest.AttributesEntry,
    map: true
  )
end

defmodule InternalApi.Stethoscope.EventRequest.AttributesEntry do
  @moduledoc false
  use Protobuf, map: true, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }
  defstruct [:key, :value]

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.Stethoscope.EventResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          event_id: String.t()
        }
  defstruct [:event_id]

  field(:event_id, 1, type: :string)
end

defmodule InternalApi.Stethoscope.GetBlobRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t(),
          uri: String.t()
        }
  defstruct [:wf_id, :uri]

  field(:wf_id, 1, type: :string)
  field(:uri, 2, type: :string)
end

defmodule InternalApi.Stethoscope.GetBlobResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          content: String.t()
        }
  defstruct [:content]

  field(:content, 1, type: :string)
end

defmodule InternalApi.Stethoscope.StethoscopeService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Stethoscope.StethoscopeService"

  rpc(:Event, InternalApi.Stethoscope.EventRequest, InternalApi.Stethoscope.EventResponse)
  rpc(:GetBlob, InternalApi.Stethoscope.GetBlobRequest, InternalApi.Stethoscope.GetBlobResponse)
end

defmodule InternalApi.Stethoscope.StethoscopeService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Stethoscope.StethoscopeService.Service
end
