defmodule InternalApi.SelfHosted.AgentType do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          name: String.t(),
          total_agent_count: integer,
          requester_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t(),
          agent_name_settings: InternalApi.SelfHosted.AgentNameSettings.t()
        }
  defstruct [
    :organization_id,
    :name,
    :total_agent_count,
    :requester_id,
    :created_at,
    :updated_at,
    :agent_name_settings
  ]

  field(:organization_id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:total_agent_count, 3, type: :int32)
  field(:requester_id, 4, type: :string)
  field(:created_at, 5, type: Google.Protobuf.Timestamp)
  field(:updated_at, 6, type: Google.Protobuf.Timestamp)
  field(:agent_name_settings, 7, type: InternalApi.SelfHosted.AgentNameSettings)
end

defmodule InternalApi.SelfHosted.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          os: String.t(),
          state: integer,
          connected_at: Google.Protobuf.Timestamp.t(),
          pid: integer,
          user_agent: String.t(),
          hostname: String.t(),
          ip_address: String.t(),
          arch: String.t(),
          disabled_at: Google.Protobuf.Timestamp.t(),
          disabled: boolean,
          type_name: String.t(),
          organization_id: String.t()
        }
  defstruct [
    :name,
    :version,
    :os,
    :state,
    :connected_at,
    :pid,
    :user_agent,
    :hostname,
    :ip_address,
    :arch,
    :disabled_at,
    :disabled,
    :type_name,
    :organization_id
  ]

  field(:name, 1, type: :string)
  field(:version, 2, type: :string)
  field(:os, 3, type: :string)
  field(:state, 4, type: InternalApi.SelfHosted.Agent.State, enum: true)
  field(:connected_at, 5, type: Google.Protobuf.Timestamp)
  field(:pid, 6, type: :int32)
  field(:user_agent, 7, type: :string)
  field(:hostname, 8, type: :string)
  field(:ip_address, 9, type: :string)
  field(:arch, 10, type: :string)
  field(:disabled_at, 11, type: Google.Protobuf.Timestamp)
  field(:disabled, 12, type: :bool)
  field(:type_name, 13, type: :string)
  field(:organization_id, 14, type: :string)
end

defmodule InternalApi.SelfHosted.Agent.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:WAITING_FOR_JOB, 0)
  field(:RUNNING_JOB, 1)
end

defmodule InternalApi.SelfHosted.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          name: String.t(),
          requester_id: String.t(),
          agent_name_settings: InternalApi.SelfHosted.AgentNameSettings.t()
        }
  defstruct [:organization_id, :name, :requester_id, :agent_name_settings]

  field(:organization_id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:requester_id, 3, type: :string)
  field(:agent_name_settings, 4, type: InternalApi.SelfHosted.AgentNameSettings)
end

defmodule InternalApi.SelfHosted.AgentNameSettings do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          assignment_origin: integer,
          aws: InternalApi.SelfHosted.AgentNameSettings.AWS.t(),
          release_after: integer
        }
  defstruct [:assignment_origin, :aws, :release_after]

  field(:assignment_origin, 1,
    type: InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin,
    enum: true
  )

  field(:aws, 2, type: InternalApi.SelfHosted.AgentNameSettings.AWS)
  field(:release_after, 3, type: :int64)
end

defmodule InternalApi.SelfHosted.AgentNameSettings.AWS do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          account_id: String.t(),
          role_name_patterns: String.t()
        }
  defstruct [:account_id, :role_name_patterns]

  field(:account_id, 2, type: :string)
  field(:role_name_patterns, 3, type: :string)
end

defmodule InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ASSIGNMENT_ORIGIN_UNSPECIFIED, 0)
  field(:ASSIGNMENT_ORIGIN_AGENT, 1)
  field(:ASSIGNMENT_ORIGIN_AWS_STS, 2)
end

defmodule InternalApi.SelfHosted.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent_type: InternalApi.SelfHosted.AgentType.t(),
          agent_registration_token: String.t()
        }
  defstruct [:agent_type, :agent_registration_token]

  field(:agent_type, 1, type: InternalApi.SelfHosted.AgentType)
  field(:agent_registration_token, 2, type: :string)
end

defmodule InternalApi.SelfHosted.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          name: String.t(),
          requester_id: String.t(),
          agent_type: InternalApi.SelfHosted.AgentType.t()
        }
  defstruct [:organization_id, :name, :requester_id, :agent_type]

  field(:organization_id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:requester_id, 3, type: :string)
  field(:agent_type, 4, type: InternalApi.SelfHosted.AgentType)
end

defmodule InternalApi.SelfHosted.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent_type: InternalApi.SelfHosted.AgentType.t()
        }
  defstruct [:agent_type]

  field(:agent_type, 1, type: InternalApi.SelfHosted.AgentType)
end

defmodule InternalApi.SelfHosted.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          name: String.t()
        }
  defstruct [:organization_id, :name]

  field(:organization_id, 1, type: :string)
  field(:name, 2, type: :string)
end

defmodule InternalApi.SelfHosted.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent_type: InternalApi.SelfHosted.AgentType.t()
        }
  defstruct [:agent_type]

  field(:agent_type, 1, type: InternalApi.SelfHosted.AgentType)
end

defmodule InternalApi.SelfHosted.DescribeAgentRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          name: String.t()
        }
  defstruct [:organization_id, :name]

  field(:organization_id, 1, type: :string)
  field(:name, 2, type: :string)
end

defmodule InternalApi.SelfHosted.DescribeAgentResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent: InternalApi.SelfHosted.Agent.t()
        }
  defstruct [:agent]

  field(:agent, 1, type: InternalApi.SelfHosted.Agent)
end

defmodule InternalApi.SelfHosted.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          page: integer
        }
  defstruct [:organization_id, :page]

  field(:organization_id, 1, type: :string)
  field(:page, 2, type: :int32)
end

defmodule InternalApi.SelfHosted.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent_types: [InternalApi.SelfHosted.AgentType.t()],
          total_count: integer,
          total_pages: integer,
          page: integer
        }
  defstruct [:agent_types, :total_count, :total_pages, :page]

  field(:agent_types, 1, repeated: true, type: InternalApi.SelfHosted.AgentType)
  field(:total_count, 2, type: :int32)
  field(:total_pages, 3, type: :int32)
  field(:page, 4, type: :int32)
end

defmodule InternalApi.SelfHosted.ListKeysetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          cursor: String.t(),
          page_size: integer
        }
  defstruct [:organization_id, :cursor, :page_size]

  field(:organization_id, 1, type: :string)
  field(:cursor, 2, type: :string)
  field(:page_size, 3, type: :int32)
end

defmodule InternalApi.SelfHosted.ListKeysetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent_types: [InternalApi.SelfHosted.AgentType.t()],
          next_page_cursor: String.t()
        }
  defstruct [:agent_types, :next_page_cursor]

  field(:agent_types, 1, repeated: true, type: InternalApi.SelfHosted.AgentType)
  field(:next_page_cursor, 2, type: :string)
end

defmodule InternalApi.SelfHosted.ListAgentsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          agent_type_name: String.t(),
          page: integer,
          page_size: integer,
          cursor: String.t()
        }
  defstruct [:organization_id, :agent_type_name, :page, :page_size, :cursor]

  field(:organization_id, 1, type: :string)
  field(:agent_type_name, 2, type: :string)
  field(:page, 3, type: :int32)
  field(:page_size, 4, type: :int32)
  field(:cursor, 5, type: :string)
end

defmodule InternalApi.SelfHosted.ListAgentsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agents: [InternalApi.SelfHosted.Agent.t()],
          total_count: integer,
          total_pages: integer,
          page: integer,
          cursor: String.t()
        }
  defstruct [:agents, :total_count, :total_pages, :page, :cursor]

  field(:agents, 1, repeated: true, type: InternalApi.SelfHosted.Agent)
  field(:total_count, 2, type: :int32)
  field(:total_pages, 3, type: :int32)
  field(:page, 4, type: :int32)
  field(:cursor, 5, type: :string)
end

defmodule InternalApi.SelfHosted.OccupyAgentRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          job_id: String.t(),
          agent_type: String.t()
        }
  defstruct [:organization_id, :job_id, :agent_type]

  field(:organization_id, 1, type: :string)
  field(:job_id, 2, type: :string)
  field(:agent_type, 3, type: :string)
end

defmodule InternalApi.SelfHosted.OccupyAgentResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          agent_id: String.t(),
          agent_name: String.t()
        }
  defstruct [:agent_id, :agent_name]

  field(:agent_id, 1, type: :string)
  field(:agent_name, 2, type: :string)
end

defmodule InternalApi.SelfHosted.ReleaseAgentRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          agent_type: String.t(),
          job_id: String.t()
        }
  defstruct [:organization_id, :agent_type, :job_id]

  field(:organization_id, 1, type: :string)
  field(:agent_type, 2, type: :string)
  field(:job_id, 3, type: :string)
end

defmodule InternalApi.SelfHosted.ReleaseAgentResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.SelfHosted.DisableAgentRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          agent_type: String.t(),
          agent_name: String.t()
        }
  defstruct [:organization_id, :agent_type, :agent_name]

  field(:organization_id, 1, type: :string)
  field(:agent_type, 2, type: :string)
  field(:agent_name, 3, type: :string)
end

defmodule InternalApi.SelfHosted.DisableAgentResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.SelfHosted.DisableAllAgentsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          agent_type: String.t(),
          only_idle: boolean
        }
  defstruct [:organization_id, :agent_type, :only_idle]

  field(:organization_id, 1, type: :string)
  field(:agent_type, 2, type: :string)
  field(:only_idle, 3, type: :bool)
end

defmodule InternalApi.SelfHosted.DisableAllAgentsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.SelfHosted.DeleteAgentTypeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          name: String.t()
        }
  defstruct [:organization_id, :name]

  field(:organization_id, 1, type: :string)
  field(:name, 2, type: :string)
end

defmodule InternalApi.SelfHosted.DeleteAgentTypeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.SelfHosted.StopJobRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          agent_type: String.t(),
          job_id: String.t()
        }
  defstruct [:organization_id, :agent_type, :job_id]

  field(:organization_id, 1, type: :string)
  field(:agent_type, 2, type: :string)
  field(:job_id, 3, type: :string)
end

defmodule InternalApi.SelfHosted.StopJobResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.SelfHosted.ResetTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          agent_type: String.t(),
          disconnect_running_agents: boolean,
          requester_id: String.t()
        }
  defstruct [:organization_id, :agent_type, :disconnect_running_agents, :requester_id]

  field(:organization_id, 1, type: :string)
  field(:agent_type, 2, type: :string)
  field(:disconnect_running_agents, 3, type: :bool)
  field(:requester_id, 4, type: :string)
end

defmodule InternalApi.SelfHosted.ResetTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          token: String.t()
        }
  defstruct [:token]

  field(:token, 1, type: :string)
end

defmodule InternalApi.SelfHosted.SelfHostedAgents.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.SelfHosted.SelfHostedAgents"

  rpc(:Create, InternalApi.SelfHosted.CreateRequest, InternalApi.SelfHosted.CreateResponse)
  rpc(:Update, InternalApi.SelfHosted.UpdateRequest, InternalApi.SelfHosted.UpdateResponse)
  rpc(:Describe, InternalApi.SelfHosted.DescribeRequest, InternalApi.SelfHosted.DescribeResponse)

  rpc(
    :DescribeAgent,
    InternalApi.SelfHosted.DescribeAgentRequest,
    InternalApi.SelfHosted.DescribeAgentResponse
  )

  rpc(:List, InternalApi.SelfHosted.ListRequest, InternalApi.SelfHosted.ListResponse)

  rpc(
    :ListKeyset,
    InternalApi.SelfHosted.ListKeysetRequest,
    InternalApi.SelfHosted.ListKeysetResponse
  )

  rpc(
    :ListAgents,
    InternalApi.SelfHosted.ListAgentsRequest,
    InternalApi.SelfHosted.ListAgentsResponse
  )

  rpc(
    :OccupyAgent,
    InternalApi.SelfHosted.OccupyAgentRequest,
    InternalApi.SelfHosted.OccupyAgentResponse
  )

  rpc(
    :ReleaseAgent,
    InternalApi.SelfHosted.ReleaseAgentRequest,
    InternalApi.SelfHosted.ReleaseAgentResponse
  )

  rpc(
    :DisableAgent,
    InternalApi.SelfHosted.DisableAgentRequest,
    InternalApi.SelfHosted.DisableAgentResponse
  )

  rpc(
    :DisableAllAgents,
    InternalApi.SelfHosted.DisableAllAgentsRequest,
    InternalApi.SelfHosted.DisableAllAgentsResponse
  )

  rpc(
    :DeleteAgentType,
    InternalApi.SelfHosted.DeleteAgentTypeRequest,
    InternalApi.SelfHosted.DeleteAgentTypeResponse
  )

  rpc(:StopJob, InternalApi.SelfHosted.StopJobRequest, InternalApi.SelfHosted.StopJobResponse)

  rpc(
    :ResetToken,
    InternalApi.SelfHosted.ResetTokenRequest,
    InternalApi.SelfHosted.ResetTokenResponse
  )
end

defmodule InternalApi.SelfHosted.SelfHostedAgents.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.SelfHosted.SelfHostedAgents.Service
end
