defmodule InternalApi.PreFlightChecksHub.PreFlightChecks do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_pfc: InternalApi.PreFlightChecksHub.OrganizationPFC.t(),
          project_pfc: InternalApi.PreFlightChecksHub.ProjectPFC.t()
        }
  defstruct [:organization_pfc, :project_pfc]

  field :organization_pfc, 1, type: InternalApi.PreFlightChecksHub.OrganizationPFC
  field :project_pfc, 2, type: InternalApi.PreFlightChecksHub.ProjectPFC
end

defmodule InternalApi.PreFlightChecksHub.OrganizationPFC do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commands: [String.t()],
          secrets: [String.t()],
          agent: InternalApi.PreFlightChecksHub.Agent.t(),
          requester_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:commands, :secrets, :agent, :requester_id, :created_at, :updated_at]

  field :commands, 1, repeated: true, type: :string
  field :secrets, 2, repeated: true, type: :string
  field :agent, 3, type: InternalApi.PreFlightChecksHub.Agent
  field :requester_id, 4, type: :string
  field :created_at, 5, type: Google.Protobuf.Timestamp
  field :updated_at, 6, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.PreFlightChecksHub.ProjectPFC do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commands: [String.t()],
          secrets: [String.t()],
          requester_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t(),
          agent: InternalApi.PreFlightChecksHub.Agent.t()
        }
  defstruct [:commands, :secrets, :requester_id, :created_at, :updated_at, :agent]

  field :commands, 1, repeated: true, type: :string
  field :secrets, 2, repeated: true, type: :string
  field :requester_id, 3, type: :string
  field :created_at, 4, type: Google.Protobuf.Timestamp
  field :updated_at, 5, type: Google.Protobuf.Timestamp
  field :agent, 6, type: InternalApi.PreFlightChecksHub.Agent
end

defmodule InternalApi.PreFlightChecksHub.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine_type: String.t(),
          os_image: String.t()
        }
  defstruct [:machine_type, :os_image]

  field :machine_type, 1, type: :string
  field :os_image, 2, type: :string
end

defmodule InternalApi.PreFlightChecksHub.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          level: integer,
          organization_id: String.t(),
          project_id: String.t()
        }
  defstruct [:level, :organization_id, :project_id]

  field :level, 1, type: InternalApi.PreFlightChecksHub.PFCLevel, enum: true
  field :organization_id, 2, type: :string
  field :project_id, 3, type: :string
end

defmodule InternalApi.PreFlightChecksHub.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          pre_flight_checks: InternalApi.PreFlightChecksHub.PreFlightChecks.t()
        }
  defstruct [:status, :pre_flight_checks]

  field :status, 1, type: InternalApi.Status
  field :pre_flight_checks, 2, type: InternalApi.PreFlightChecksHub.PreFlightChecks
end

defmodule InternalApi.PreFlightChecksHub.ApplyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          level: integer,
          organization_id: String.t(),
          project_id: String.t(),
          requester_id: String.t(),
          pre_flight_checks: InternalApi.PreFlightChecksHub.PreFlightChecks.t()
        }
  defstruct [:level, :organization_id, :project_id, :requester_id, :pre_flight_checks]

  field :level, 1, type: InternalApi.PreFlightChecksHub.PFCLevel, enum: true
  field :organization_id, 2, type: :string
  field :project_id, 3, type: :string
  field :requester_id, 4, type: :string
  field :pre_flight_checks, 5, type: InternalApi.PreFlightChecksHub.PreFlightChecks
end

defmodule InternalApi.PreFlightChecksHub.ApplyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          pre_flight_checks: InternalApi.PreFlightChecksHub.PreFlightChecks.t()
        }
  defstruct [:status, :pre_flight_checks]

  field :status, 1, type: InternalApi.Status
  field :pre_flight_checks, 2, type: InternalApi.PreFlightChecksHub.PreFlightChecks
end

defmodule InternalApi.PreFlightChecksHub.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          level: integer,
          organization_id: String.t(),
          project_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:level, :organization_id, :project_id, :requester_id]

  field :level, 1, type: InternalApi.PreFlightChecksHub.PFCLevel, enum: true
  field :organization_id, 2, type: :string
  field :project_id, 3, type: :string
  field :requester_id, 4, type: :string
end

defmodule InternalApi.PreFlightChecksHub.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t()
        }
  defstruct [:status]

  field :status, 1, type: InternalApi.Status
end

defmodule InternalApi.PreFlightChecksHub.PFCLevel do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :ORGANIZATION, 0
  field :PROJECT, 1
  field :EVERYTHING, 2
end

defmodule InternalApi.PreFlightChecksHub.PreFlightChecksService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.PreFlightChecksHub.PreFlightChecksService"

  rpc :Describe,
      InternalApi.PreFlightChecksHub.DescribeRequest,
      InternalApi.PreFlightChecksHub.DescribeResponse

  rpc :Apply,
      InternalApi.PreFlightChecksHub.ApplyRequest,
      InternalApi.PreFlightChecksHub.ApplyResponse

  rpc :Destroy,
      InternalApi.PreFlightChecksHub.DestroyRequest,
      InternalApi.PreFlightChecksHub.DestroyResponse
end

defmodule InternalApi.PreFlightChecksHub.PreFlightChecksService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.PreFlightChecksHub.PreFlightChecksService.Service
end
