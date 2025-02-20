defmodule InternalApi.Chmura.OccupyAgentRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          request_id: String.t(),
          machine: InternalApi.Chmura.Agent.Machine.t()
        }
  defstruct [:request_id, :machine]

  field(:request_id, 1, type: :string)
  field(:machine, 2, type: InternalApi.Chmura.Agent.Machine)
end

defmodule InternalApi.Chmura.OccupyAgentResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent: InternalApi.Chmura.Agent.t()
        }
  defstruct [:agent]

  field(:agent, 2, type: InternalApi.Chmura.Agent)
end

defmodule InternalApi.Chmura.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          machine: InternalApi.Chmura.Agent.Machine.t(),
          ip_address: String.t(),
          ctrl_port: integer,
          ssh_port: integer,
          auth_token: String.t()
        }
  defstruct [:id, :machine, :ip_address, :ctrl_port, :ssh_port, :auth_token]

  field(:id, 1, type: :string)
  field(:machine, 2, type: InternalApi.Chmura.Agent.Machine)
  field(:ip_address, 3, type: :string)
  field(:ctrl_port, 4, type: :int32)
  field(:ssh_port, 5, type: :int32)
  field(:auth_token, 6, type: :string)
end

defmodule InternalApi.Chmura.Agent.Machine do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: String.t(),
          os_image: String.t()
        }
  defstruct [:type, :os_image]

  field(:type, 1, type: :string)
  field(:os_image, 2, type: :string)
end

defmodule InternalApi.Chmura.ReleaseAgentRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent_id: String.t()
        }
  defstruct [:agent_id]

  field(:agent_id, 1, type: :string)
end

defmodule InternalApi.Chmura.ReleaseAgentResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Chmura.Chmura.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Chmura.Chmura"

  rpc(:OccupyAgent, InternalApi.Chmura.OccupyAgentRequest, InternalApi.Chmura.OccupyAgentResponse)

  rpc(
    :ReleaseAgent,
    InternalApi.Chmura.ReleaseAgentRequest,
    InternalApi.Chmura.ReleaseAgentResponse
  )
end

defmodule InternalApi.Chmura.Chmura.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Chmura.Chmura.Service
end
