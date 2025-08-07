defmodule InternalApi.ServerFarm.Job.DebugSessionType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:JOB, 0)
  field(:PROJECT, 1)
end

defmodule InternalApi.ServerFarm.Job.Job.State do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:PENDING, 0)
  field(:ENQUEUED, 1)
  field(:SCHEDULED, 2)
  field(:DISPATCHED, 5)
  field(:STARTED, 3)
  field(:FINISHED, 4)
end

defmodule InternalApi.ServerFarm.Job.Job.Result do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.ServerFarm.Job.ListRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BY_FINISH_TIME_ASC, 0)
  field(:BY_CREATION_TIME_DESC, 1)
  field(:BY_PRIORITY_DESC, 2)
end

defmodule InternalApi.ServerFarm.Job.ListDebugSessionsRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BY_CREATION_TIME_DESC, 0)
  field(:BY_FINISH_TIME_ASC, 1)
end

defmodule InternalApi.ServerFarm.Job.TotalExecutionTimeRequest.Interval do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:LAST_DAY, 0)
end

defmodule InternalApi.ServerFarm.Job.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
end

defmodule InternalApi.ServerFarm.Job.Job.Timeline do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:created_at, 1, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:enqueued_at, 2, type: Google.Protobuf.Timestamp, json_name: "enqueuedAt")
  field(:started_at, 3, type: Google.Protobuf.Timestamp, json_name: "startedAt")
  field(:finished_at, 4, type: Google.Protobuf.Timestamp, json_name: "finishedAt")

  field(:execution_started_at, 5,
    type: Google.Protobuf.Timestamp,
    json_name: "executionStartedAt"
  )

  field(:execution_finished_at, 6,
    type: Google.Protobuf.Timestamp,
    json_name: "executionFinishedAt"
  )
end

defmodule InternalApi.ServerFarm.Job.Job do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:branch_id, 3, type: :string, json_name: "branchId")
  field(:hook_id, 4, type: :string, json_name: "hookId")
  field(:timeline, 5, type: InternalApi.ServerFarm.Job.Job.Timeline)
  field(:state, 6, type: InternalApi.ServerFarm.Job.Job.State, enum: true)
  field(:result, 7, type: InternalApi.ServerFarm.Job.Job.Result, enum: true)
  field(:build_server_ip, 8, type: :string, json_name: "buildServerIp")
  field(:ppl_id, 9, type: :string, json_name: "pplId")
  field(:name, 10, type: :string)
  field(:index, 11, type: :int32)
  field(:failure_reason, 12, type: :string, json_name: "failureReason")
  field(:machine_type, 13, type: :string, json_name: "machineType")
  field(:machine_os_image, 14, type: :string, json_name: "machineOsImage")
  field(:agent_host, 15, type: :string, json_name: "agentHost")
  field(:agent_ctrl_port, 16, type: :int32, json_name: "agentCtrlPort")
  field(:agent_ssh_port, 17, type: :int32, json_name: "agentSshPort")
  field(:agent_auth_token, 18, type: :string, json_name: "agentAuthToken")
  field(:priority, 19, type: :int32)
  field(:is_debug_job, 20, type: :bool, json_name: "isDebugJob")
  field(:debug_user_id, 21, type: :string, json_name: "debugUserId")
  field(:self_hosted, 22, type: :bool, json_name: "selfHosted")
  field(:organization_id, 23, type: :string, json_name: "organizationId")
  field(:build_req_id, 24, type: :string, json_name: "buildReqId")
  field(:agent_name, 25, type: :string, json_name: "agentName")
  field(:agent_id, 27, type: :string, json_name: "agentId")
end

defmodule InternalApi.ServerFarm.Job.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:job, 2, type: InternalApi.ServerFarm.Job.Job)
end

defmodule InternalApi.ServerFarm.Job.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:page_size, 1, type: :int32, json_name: "pageSize")
  field(:page_token, 2, type: :string, json_name: "pageToken")
  field(:order, 3, type: InternalApi.ServerFarm.Job.ListRequest.Order, enum: true)

  field(:job_states, 4,
    repeated: true,
    type: InternalApi.ServerFarm.Job.Job.State,
    json_name: "jobStates",
    enum: true
  )

  field(:finished_at_gt, 5, type: Google.Protobuf.Timestamp, json_name: "finishedAtGt")
  field(:finished_at_gte, 6, type: Google.Protobuf.Timestamp, json_name: "finishedAtGte")
  field(:organization_id, 7, type: :string, json_name: "organizationId")
  field(:only_debug_jobs, 8, type: :bool, json_name: "onlyDebugJobs")
  field(:ppl_ids, 9, repeated: true, type: :string, json_name: "pplIds")
  field(:created_at_gte, 10, type: Google.Protobuf.Timestamp, json_name: "createdAtGte")
  field(:created_at_lte, 11, type: Google.Protobuf.Timestamp, json_name: "createdAtLte")
  field(:project_ids, 13, repeated: true, type: :string, json_name: "projectIds")
  field(:machine_types, 14, repeated: true, type: :string, json_name: "machineTypes")
end

defmodule InternalApi.ServerFarm.Job.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:jobs, 2, repeated: true, type: InternalApi.ServerFarm.Job.Job)
  field(:next_page_token, 3, type: :string, json_name: "nextPageToken")
end

defmodule InternalApi.ServerFarm.Job.ListDebugSessionsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:page_size, 1, type: :int32, json_name: "pageSize")
  field(:page_token, 2, type: :string, json_name: "pageToken")
  field(:order, 3, type: InternalApi.ServerFarm.Job.ListDebugSessionsRequest.Order, enum: true)

  field(:debug_session_states, 4,
    repeated: true,
    type: InternalApi.ServerFarm.Job.Job.State,
    json_name: "debugSessionStates",
    enum: true
  )

  field(:types, 5, repeated: true, type: InternalApi.ServerFarm.Job.DebugSessionType, enum: true)
  field(:organization_id, 6, type: :string, json_name: "organizationId")
  field(:project_id, 7, type: :string, json_name: "projectId")
  field(:job_id, 8, type: :string, json_name: "jobId")
  field(:debug_user_id, 9, type: :string, json_name: "debugUserId")
end

defmodule InternalApi.ServerFarm.Job.ListDebugSessionsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)

  field(:debug_sessions, 2,
    repeated: true,
    type: InternalApi.ServerFarm.Job.DebugSession,
    json_name: "debugSessions"
  )

  field(:next_page_token, 3, type: :string, json_name: "nextPageToken")
end

defmodule InternalApi.ServerFarm.Job.DebugSession do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:debug_session, 1, type: InternalApi.ServerFarm.Job.Job, json_name: "debugSession")
  field(:type, 2, type: InternalApi.ServerFarm.Job.DebugSessionType, enum: true)
  field(:debug_user_id, 3, type: :string, json_name: "debugUserId")
  field(:debugged_job, 4, type: InternalApi.ServerFarm.Job.Job, json_name: "debuggedJob")
end

defmodule InternalApi.ServerFarm.Job.CountRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:job_states, 4,
    repeated: true,
    type: InternalApi.ServerFarm.Job.Job.State,
    json_name: "jobStates",
    enum: true
  )

  field(:finished_at_gte, 1, type: Google.Protobuf.Timestamp, json_name: "finishedAtGte")
  field(:finished_at_lte, 2, type: Google.Protobuf.Timestamp, json_name: "finishedAtLte")
end

defmodule InternalApi.ServerFarm.Job.CountResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:count, 2, type: :int32)
end

defmodule InternalApi.ServerFarm.Job.CountByStateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:agent_type, 2, type: :string, json_name: "agentType")
  field(:states, 3, repeated: true, type: InternalApi.ServerFarm.Job.Job.State, enum: true)
end

defmodule InternalApi.ServerFarm.Job.CountByStateResponse.CountByState do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:state, 1, type: InternalApi.ServerFarm.Job.Job.State, enum: true)
  field(:count, 2, type: :int32)
end

defmodule InternalApi.ServerFarm.Job.CountByStateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:counts, 1,
    repeated: true,
    type: InternalApi.ServerFarm.Job.CountByStateResponse.CountByState
  )
end

defmodule InternalApi.ServerFarm.Job.TotalExecutionTimeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")

  field(:interval, 2,
    type: InternalApi.ServerFarm.Job.TotalExecutionTimeRequest.Interval,
    enum: true
  )
end

defmodule InternalApi.ServerFarm.Job.TotalExecutionTimeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:total_duration_in_secs, 1, type: :int64, json_name: "totalDurationInSecs")
end

defmodule InternalApi.ServerFarm.Job.StopRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
  field(:requester_id, 2, type: :string, json_name: "requesterId")
end

defmodule InternalApi.ServerFarm.Job.StopResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.ServerFarm.Job.GetAgentPayloadRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
end

defmodule InternalApi.ServerFarm.Job.GetAgentPayloadResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:payload, 1, type: :string)
end

defmodule InternalApi.ServerFarm.Job.CanDebugRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
  field(:user_id, 2, type: :string, json_name: "userId")
end

defmodule InternalApi.ServerFarm.Job.CanDebugResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:allowed, 1, type: :bool)
  field(:message, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.CanAttachRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
  field(:user_id, 2, type: :string, json_name: "userId")
end

defmodule InternalApi.ServerFarm.Job.CanAttachResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:allowed, 1, type: :bool)
  field(:message, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:requester_id, 1, type: :string, json_name: "requesterId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
  field(:project_id, 3, type: :string, json_name: "projectId")
  field(:branch_name, 4, type: :string, json_name: "branchName")
  field(:commit_sha, 5, type: :string, json_name: "commitSha")
  field(:job_spec, 6, type: InternalApi.ServerFarm.Job.JobSpec, json_name: "jobSpec")
  field(:restricted_job, 7, type: :bool, json_name: "restrictedJob")
end

defmodule InternalApi.ServerFarm.Job.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:job, 2, type: InternalApi.ServerFarm.Job.Job)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Agent.Machine do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:type, 1, type: :string)
  field(:os_image, 2, type: :string, json_name: "osImage")
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Agent.Container do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:image, 2, type: :string)
  field(:command, 3, type: :string)

  field(:env_vars, 4,
    repeated: true,
    type: InternalApi.ServerFarm.Job.JobSpec.EnvVar,
    json_name: "envVars"
  )

  field(:secrets, 5, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.Secret)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Agent.ImagePullSecret do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Agent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:machine, 1, type: InternalApi.ServerFarm.Job.JobSpec.Agent.Machine)
  field(:containers, 2, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.Agent.Container)

  field(:image_pull_secrets, 3,
    repeated: true,
    type: InternalApi.ServerFarm.Job.JobSpec.Agent.ImagePullSecret,
    json_name: "imagePullSecrets"
  )
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Secret do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.EnvVar do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.File do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:path, 1, type: :string)
  field(:content, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.JobSpec do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:job_name, 1, type: :string, json_name: "jobName")
  field(:agent, 2, type: InternalApi.ServerFarm.Job.JobSpec.Agent)
  field(:secrets, 3, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.Secret)

  field(:env_vars, 4,
    repeated: true,
    type: InternalApi.ServerFarm.Job.JobSpec.EnvVar,
    json_name: "envVars"
  )

  field(:files, 5, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.File)
  field(:commands, 6, repeated: true, type: :string)

  field(:epilogue_always_commands, 7,
    repeated: true,
    type: :string,
    json_name: "epilogueAlwaysCommands"
  )

  field(:epilogue_on_pass_commands, 8,
    repeated: true,
    type: :string,
    json_name: "epilogueOnPassCommands"
  )

  field(:epilogue_on_fail_commands, 9,
    repeated: true,
    type: :string,
    json_name: "epilogueOnFailCommands"
  )

  field(:priority, 10, type: :int32)
  field(:execution_time_limit, 11, type: :int32, json_name: "executionTimeLimit")
end

defmodule InternalApi.ServerFarm.Job.JobService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.ServerFarm.Job.JobService",
    protoc_gen_elixir_version: "0.12.0"

  rpc(
    :Describe,
    InternalApi.ServerFarm.Job.DescribeRequest,
    InternalApi.ServerFarm.Job.DescribeResponse
  )

  rpc(:List, InternalApi.ServerFarm.Job.ListRequest, InternalApi.ServerFarm.Job.ListResponse)

  rpc(
    :ListDebugSessions,
    InternalApi.ServerFarm.Job.ListDebugSessionsRequest,
    InternalApi.ServerFarm.Job.ListDebugSessionsResponse
  )

  rpc(:Count, InternalApi.ServerFarm.Job.CountRequest, InternalApi.ServerFarm.Job.CountResponse)

  rpc(
    :CountByState,
    InternalApi.ServerFarm.Job.CountByStateRequest,
    InternalApi.ServerFarm.Job.CountByStateResponse
  )

  rpc(:Stop, InternalApi.ServerFarm.Job.StopRequest, InternalApi.ServerFarm.Job.StopResponse)

  rpc(
    :TotalExecutionTime,
    InternalApi.ServerFarm.Job.TotalExecutionTimeRequest,
    InternalApi.ServerFarm.Job.TotalExecutionTimeResponse
  )

  rpc(
    :GetAgentPayload,
    InternalApi.ServerFarm.Job.GetAgentPayloadRequest,
    InternalApi.ServerFarm.Job.GetAgentPayloadResponse
  )

  rpc(
    :CanDebug,
    InternalApi.ServerFarm.Job.CanDebugRequest,
    InternalApi.ServerFarm.Job.CanDebugResponse
  )

  rpc(
    :CanAttach,
    InternalApi.ServerFarm.Job.CanAttachRequest,
    InternalApi.ServerFarm.Job.CanAttachResponse
  )

  rpc(
    :Create,
    InternalApi.ServerFarm.Job.CreateRequest,
    InternalApi.ServerFarm.Job.CreateResponse
  )
end

defmodule InternalApi.ServerFarm.Job.JobService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.ServerFarm.Job.JobService.Service
end
