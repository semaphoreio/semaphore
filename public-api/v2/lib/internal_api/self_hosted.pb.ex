defmodule InternalApi.SelfHosted.Agent.State do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:WAITING_FOR_JOB, 0)
  field(:RUNNING_JOB, 1)
end

defmodule InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:ASSIGNMENT_ORIGIN_UNSPECIFIED, 0)
  field(:ASSIGNMENT_ORIGIN_AGENT, 1)
  field(:ASSIGNMENT_ORIGIN_AWS_STS, 2)
end

defmodule InternalApi.SelfHosted.AgentType do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:name, 2, type: :string)
  field(:total_agent_count, 3, type: :int32, json_name: "totalAgentCount")
  field(:requester_id, 4, type: :string, json_name: "requesterId")
  field(:created_at, 5, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 6, type: Google.Protobuf.Timestamp, json_name: "updatedAt")

  field(:agent_name_settings, 7,
    type: InternalApi.SelfHosted.AgentNameSettings,
    json_name: "agentNameSettings"
  )
end

defmodule InternalApi.SelfHosted.Agent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:version, 2, type: :string)
  field(:os, 3, type: :string)
  field(:state, 4, type: InternalApi.SelfHosted.Agent.State, enum: true)
  field(:connected_at, 5, type: Google.Protobuf.Timestamp, json_name: "connectedAt")
  field(:pid, 6, type: :int32)
  field(:user_agent, 7, type: :string, json_name: "userAgent")
  field(:hostname, 8, type: :string)
  field(:ip_address, 9, type: :string, json_name: "ipAddress")
  field(:arch, 10, type: :string)
  field(:disabled_at, 11, type: Google.Protobuf.Timestamp, json_name: "disabledAt")
  field(:disabled, 12, type: :bool)
  field(:type_name, 13, type: :string, json_name: "typeName")
  field(:organization_id, 14, type: :string, json_name: "organizationId")
end

defmodule InternalApi.SelfHosted.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:name, 2, type: :string)
  field(:requester_id, 3, type: :string, json_name: "requesterId")

  field(:agent_name_settings, 4,
    type: InternalApi.SelfHosted.AgentNameSettings,
    json_name: "agentNameSettings"
  )
end

defmodule InternalApi.SelfHosted.AgentNameSettings.AWS do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:account_id, 2, type: :string, json_name: "accountId")
  field(:role_name_patterns, 3, type: :string, json_name: "roleNamePatterns")
end

defmodule InternalApi.SelfHosted.AgentNameSettings do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:assignment_origin, 1,
    type: InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin,
    json_name: "assignmentOrigin",
    enum: true
  )

  field(:aws, 2, type: InternalApi.SelfHosted.AgentNameSettings.AWS)
  field(:release_after, 3, type: :int64, json_name: "releaseAfter")
end

defmodule InternalApi.SelfHosted.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:agent_type, 1, type: InternalApi.SelfHosted.AgentType, json_name: "agentType")
  field(:agent_registration_token, 2, type: :string, json_name: "agentRegistrationToken")
end

defmodule InternalApi.SelfHosted.UpdateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:name, 2, type: :string)
  field(:requester_id, 3, type: :string, json_name: "requesterId")
  field(:agent_type, 4, type: InternalApi.SelfHosted.AgentType, json_name: "agentType")
end

defmodule InternalApi.SelfHosted.UpdateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:agent_type, 1, type: InternalApi.SelfHosted.AgentType, json_name: "agentType")
end

defmodule InternalApi.SelfHosted.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:name, 2, type: :string)
end

defmodule InternalApi.SelfHosted.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:agent_type, 1, type: InternalApi.SelfHosted.AgentType, json_name: "agentType")
end

defmodule InternalApi.SelfHosted.DescribeAgentRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:name, 2, type: :string)
end

defmodule InternalApi.SelfHosted.DescribeAgentResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:agent, 1, type: InternalApi.SelfHosted.Agent)
end

defmodule InternalApi.SelfHosted.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:page, 2, type: :int32)
end

defmodule InternalApi.SelfHosted.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:agent_types, 1,
    repeated: true,
    type: InternalApi.SelfHosted.AgentType,
    json_name: "agentTypes"
  )

  field(:total_count, 2, type: :int32, json_name: "totalCount")
  field(:total_pages, 3, type: :int32, json_name: "totalPages")
  field(:page, 4, type: :int32)
end

defmodule InternalApi.SelfHosted.ListKeysetRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:cursor, 2, type: :string)
  field(:page_size, 3, type: :int32, json_name: "pageSize")
end

defmodule InternalApi.SelfHosted.ListKeysetResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:agent_types, 1,
    repeated: true,
    type: InternalApi.SelfHosted.AgentType,
    json_name: "agentTypes"
  )

  field(:next_page_cursor, 2, type: :string, json_name: "nextPageCursor")
end

defmodule InternalApi.SelfHosted.ListAgentsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:agent_type_name, 2, type: :string, json_name: "agentTypeName")
  field(:page, 3, type: :int32)
  field(:page_size, 4, type: :int32, json_name: "pageSize")
  field(:cursor, 5, type: :string)
end

defmodule InternalApi.SelfHosted.ListAgentsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:agents, 1, repeated: true, type: InternalApi.SelfHosted.Agent)
  field(:total_count, 2, type: :int32, json_name: "totalCount")
  field(:total_pages, 3, type: :int32, json_name: "totalPages")
  field(:page, 4, type: :int32)
  field(:cursor, 5, type: :string)
end

defmodule InternalApi.SelfHosted.OccupyAgentRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:job_id, 2, type: :string, json_name: "jobId")
  field(:agent_type, 3, type: :string, json_name: "agentType")
end

defmodule InternalApi.SelfHosted.OccupyAgentResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:agent_id, 1, type: :string, json_name: "agentId")
  field(:agent_name, 2, type: :string, json_name: "agentName")
end

defmodule InternalApi.SelfHosted.ReleaseAgentRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:agent_type, 2, type: :string, json_name: "agentType")
  field(:job_id, 3, type: :string, json_name: "jobId")
end

defmodule InternalApi.SelfHosted.ReleaseAgentResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.SelfHosted.DisableAgentRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:agent_type, 2, type: :string, json_name: "agentType")
  field(:agent_name, 3, type: :string, json_name: "agentName")
end

defmodule InternalApi.SelfHosted.DisableAgentResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.SelfHosted.DisableAllAgentsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:agent_type, 2, type: :string, json_name: "agentType")
  field(:only_idle, 3, type: :bool, json_name: "onlyIdle")
end

defmodule InternalApi.SelfHosted.DisableAllAgentsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.SelfHosted.DeleteAgentTypeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:name, 2, type: :string)
end

defmodule InternalApi.SelfHosted.DeleteAgentTypeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.SelfHosted.StopJobRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:agent_type, 2, type: :string, json_name: "agentType")
  field(:job_id, 3, type: :string, json_name: "jobId")
end

defmodule InternalApi.SelfHosted.StopJobResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.SelfHosted.ResetTokenRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:agent_type, 2, type: :string, json_name: "agentType")
  field(:disconnect_running_agents, 3, type: :bool, json_name: "disconnectRunningAgents")
  field(:requester_id, 4, type: :string, json_name: "requesterId")
end

defmodule InternalApi.SelfHosted.ResetTokenResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:token, 1, type: :string)
end

defmodule InternalApi.SelfHosted.SelfHostedAgents.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.SelfHosted.SelfHostedAgents",
    protoc_gen_elixir_version: "0.12.0"

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
