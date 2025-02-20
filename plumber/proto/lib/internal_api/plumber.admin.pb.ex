defmodule InternalApi.Plumber.GetYamlRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_id: String.t()
        }
  defstruct [:ppl_id]

  field :ppl_id, 1, type: :string
end

defmodule InternalApi.Plumber.GetYamlResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          yaml: String.t()
        }
  defstruct [:response_status, :yaml]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :yaml, 2, type: :string
end

defmodule InternalApi.Plumber.TerminateAllRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          requester_token: String.t(),
          project_id: String.t(),
          branch_name: String.t(),
          reason: integer
        }
  defstruct [:requester_token, :project_id, :branch_name, :reason]

  field :requester_token, 1, type: :string
  field :project_id, 2, type: :string
  field :branch_name, 3, type: :string
  field :reason, 4, type: InternalApi.Plumber.TerminateAllRequest.Reason, enum: true
end

defmodule InternalApi.Plumber.TerminateAllRequest.Reason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :ADMIN_ACTION, 0
  field :BRANCH_DELETION, 1
end

defmodule InternalApi.Plumber.TerminateAllResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t()
        }
  defstruct [:response_status]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
end

defmodule InternalApi.Plumber.Admin.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Plumber.Admin"

  rpc :TerminateAll,
      InternalApi.Plumber.TerminateAllRequest,
      InternalApi.Plumber.TerminateAllResponse

  rpc :GetYaml, InternalApi.Plumber.GetYamlRequest, InternalApi.Plumber.GetYamlResponse
end

defmodule InternalApi.Plumber.Admin.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Plumber.Admin.Service
end
