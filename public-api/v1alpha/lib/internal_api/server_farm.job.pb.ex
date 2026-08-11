defmodule InternalApi.ServerFarm.Job.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t()
        }
  defstruct [:job_id]

  field(:job_id, 1, type: :string)
end

defmodule InternalApi.ServerFarm.Job.Job do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          project_id: String.t(),
          branch_id: String.t(),
          hook_id: String.t(),
          timeline: InternalApi.ServerFarm.Job.Job.Timeline.t(),
          state: integer,
          result: integer,
          build_server_ip: String.t(),
          ppl_id: String.t(),
          name: String.t(),
          index: integer,
          failure_reason: String.t(),
          machine_type: String.t(),
          machine_os_image: String.t(),
          agent_host: String.t(),
          agent_ctrl_port: integer,
          agent_ssh_port: integer,
          agent_auth_token: String.t(),
          priority: integer,
          is_debug_job: boolean,
          debug_user_id: String.t(),
          self_hosted: boolean,
          organization_id: String.t(),
          build_req_id: String.t(),
          agent_name: String.t(),
          agent_id: String.t()
        }
  defstruct [
    :id,
    :project_id,
    :branch_id,
    :hook_id,
    :timeline,
    :state,
    :result,
    :build_server_ip,
    :ppl_id,
    :name,
    :index,
    :failure_reason,
    :machine_type,
    :machine_os_image,
    :agent_host,
    :agent_ctrl_port,
    :agent_ssh_port,
    :agent_auth_token,
    :priority,
    :is_debug_job,
    :debug_user_id,
    :self_hosted,
    :organization_id,
    :build_req_id,
    :agent_name,
    :agent_id
  ]

  field(:id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:branch_id, 3, type: :string)
  field(:hook_id, 4, type: :string)
  field(:timeline, 5, type: InternalApi.ServerFarm.Job.Job.Timeline)
  field(:state, 6, type: InternalApi.ServerFarm.Job.Job.State, enum: true)
  field(:result, 7, type: InternalApi.ServerFarm.Job.Job.Result, enum: true)
  field(:build_server_ip, 8, type: :string)
  field(:ppl_id, 9, type: :string)
  field(:name, 10, type: :string)
  field(:index, 11, type: :int32)
  field(:failure_reason, 12, type: :string)
  field(:machine_type, 13, type: :string)
  field(:machine_os_image, 14, type: :string)
  field(:agent_host, 15, type: :string)
  field(:agent_ctrl_port, 16, type: :int32)
  field(:agent_ssh_port, 17, type: :int32)
  field(:agent_auth_token, 18, type: :string)
  field(:priority, 19, type: :int32)
  field(:is_debug_job, 20, type: :bool)
  field(:debug_user_id, 21, type: :string)
  field(:self_hosted, 22, type: :bool)
  field(:organization_id, 23, type: :string)
  field(:build_req_id, 24, type: :string)
  field(:agent_name, 25, type: :string)
  field(:agent_id, 27, type: :string)
end

defmodule InternalApi.ServerFarm.Job.Job.Timeline do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          created_at: Google.Protobuf.Timestamp.t(),
          enqueued_at: Google.Protobuf.Timestamp.t(),
          started_at: Google.Protobuf.Timestamp.t(),
          finished_at: Google.Protobuf.Timestamp.t(),
          execution_started_at: Google.Protobuf.Timestamp.t(),
          execution_finished_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :created_at,
    :enqueued_at,
    :started_at,
    :finished_at,
    :execution_started_at,
    :execution_finished_at
  ]

  field(:created_at, 1, type: Google.Protobuf.Timestamp)
  field(:enqueued_at, 2, type: Google.Protobuf.Timestamp)
  field(:started_at, 3, type: Google.Protobuf.Timestamp)
  field(:finished_at, 4, type: Google.Protobuf.Timestamp)
  field(:execution_started_at, 5, type: Google.Protobuf.Timestamp)
  field(:execution_finished_at, 6, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.ServerFarm.Job.Job.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PENDING, 0)
  field(:ENQUEUED, 1)
  field(:SCHEDULED, 2)
  field(:DISPATCHED, 5)
  field(:STARTED, 3)
  field(:FINISHED, 4)
end

defmodule InternalApi.ServerFarm.Job.Job.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.ServerFarm.Job.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          job: InternalApi.ServerFarm.Job.Job.t()
        }
  defstruct [:status, :job]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:job, 2, type: InternalApi.ServerFarm.Job.Job)
end

defmodule InternalApi.ServerFarm.Job.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: integer,
          job_states: [integer],
          finished_at_gt: Google.Protobuf.Timestamp.t(),
          finished_at_gte: Google.Protobuf.Timestamp.t(),
          organization_id: String.t(),
          only_debug_jobs: boolean,
          ppl_ids: [String.t()],
          created_at_gte: Google.Protobuf.Timestamp.t(),
          created_at_lte: Google.Protobuf.Timestamp.t(),
          project_ids: [String.t()],
          machine_types: [String.t()]
        }
  defstruct [
    :page_size,
    :page_token,
    :order,
    :job_states,
    :finished_at_gt,
    :finished_at_gte,
    :organization_id,
    :only_debug_jobs,
    :ppl_ids,
    :created_at_gte,
    :created_at_lte,
    :project_ids,
    :machine_types
  ]

  field(:page_size, 1, type: :int32)
  field(:page_token, 2, type: :string)
  field(:order, 3, type: InternalApi.ServerFarm.Job.ListRequest.Order, enum: true)
  field(:job_states, 4, repeated: true, type: InternalApi.ServerFarm.Job.Job.State, enum: true)
  field(:finished_at_gt, 5, type: Google.Protobuf.Timestamp)
  field(:finished_at_gte, 6, type: Google.Protobuf.Timestamp)
  field(:organization_id, 7, type: :string)
  field(:only_debug_jobs, 8, type: :bool)
  field(:ppl_ids, 9, repeated: true, type: :string)
  field(:created_at_gte, 10, type: Google.Protobuf.Timestamp)
  field(:created_at_lte, 11, type: Google.Protobuf.Timestamp)
  field(:project_ids, 13, repeated: true, type: :string)
  field(:machine_types, 14, repeated: true, type: :string)
end

defmodule InternalApi.ServerFarm.Job.ListRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BY_FINISH_TIME_ASC, 0)
  field(:BY_CREATION_TIME_DESC, 1)
  field(:BY_PRIORITY_DESC, 2)
end

defmodule InternalApi.ServerFarm.Job.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          jobs: [InternalApi.ServerFarm.Job.Job.t()],
          next_page_token: String.t()
        }
  defstruct [:status, :jobs, :next_page_token]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:jobs, 2, repeated: true, type: InternalApi.ServerFarm.Job.Job)
  field(:next_page_token, 3, type: :string)
end

defmodule InternalApi.ServerFarm.Job.ListDebugSessionsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: integer,
          debug_session_states: [integer],
          types: [integer],
          organization_id: String.t(),
          project_id: String.t(),
          job_id: String.t(),
          debug_user_id: String.t()
        }
  defstruct [
    :page_size,
    :page_token,
    :order,
    :debug_session_states,
    :types,
    :organization_id,
    :project_id,
    :job_id,
    :debug_user_id
  ]

  field(:page_size, 1, type: :int32)
  field(:page_token, 2, type: :string)
  field(:order, 3, type: InternalApi.ServerFarm.Job.ListDebugSessionsRequest.Order, enum: true)

  field(:debug_session_states, 4,
    repeated: true,
    type: InternalApi.ServerFarm.Job.Job.State,
    enum: true
  )

  field(:types, 5, repeated: true, type: InternalApi.ServerFarm.Job.DebugSessionType, enum: true)
  field(:organization_id, 6, type: :string)
  field(:project_id, 7, type: :string)
  field(:job_id, 8, type: :string)
  field(:debug_user_id, 9, type: :string)
end

defmodule InternalApi.ServerFarm.Job.ListDebugSessionsRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BY_CREATION_TIME_DESC, 0)
  field(:BY_FINISH_TIME_ASC, 1)
end

defmodule InternalApi.ServerFarm.Job.ListDebugSessionsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          debug_sessions: [InternalApi.ServerFarm.Job.DebugSession.t()],
          next_page_token: String.t()
        }
  defstruct [:status, :debug_sessions, :next_page_token]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:debug_sessions, 2, repeated: true, type: InternalApi.ServerFarm.Job.DebugSession)
  field(:next_page_token, 3, type: :string)
end

defmodule InternalApi.ServerFarm.Job.DebugSession do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          debug_session: InternalApi.ServerFarm.Job.Job.t(),
          type: integer,
          debug_user_id: String.t(),
          debugged_job: InternalApi.ServerFarm.Job.Job.t()
        }
  defstruct [:debug_session, :type, :debug_user_id, :debugged_job]

  field(:debug_session, 1, type: InternalApi.ServerFarm.Job.Job)
  field(:type, 2, type: InternalApi.ServerFarm.Job.DebugSessionType, enum: true)
  field(:debug_user_id, 3, type: :string)
  field(:debugged_job, 4, type: InternalApi.ServerFarm.Job.Job)
end

defmodule InternalApi.ServerFarm.Job.CountRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_states: [integer],
          finished_at_gte: Google.Protobuf.Timestamp.t(),
          finished_at_lte: Google.Protobuf.Timestamp.t()
        }
  defstruct [:job_states, :finished_at_gte, :finished_at_lte]

  field(:job_states, 4, repeated: true, type: InternalApi.ServerFarm.Job.Job.State, enum: true)
  field(:finished_at_gte, 1, type: Google.Protobuf.Timestamp)
  field(:finished_at_lte, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.ServerFarm.Job.CountResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          count: integer
        }
  defstruct [:status, :count]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:count, 2, type: :int32)
end

defmodule InternalApi.ServerFarm.Job.CountByStateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          agent_type: String.t(),
          states: [integer]
        }
  defstruct [:org_id, :agent_type, :states]

  field(:org_id, 1, type: :string)
  field(:agent_type, 2, type: :string)
  field(:states, 3, repeated: true, type: InternalApi.ServerFarm.Job.Job.State, enum: true)
end

defmodule InternalApi.ServerFarm.Job.CountByStateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          counts: [InternalApi.ServerFarm.Job.CountByStateResponse.CountByState.t()]
        }
  defstruct [:counts]

  field(:counts, 1,
    repeated: true,
    type: InternalApi.ServerFarm.Job.CountByStateResponse.CountByState
  )
end

defmodule InternalApi.ServerFarm.Job.CountByStateResponse.CountByState do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: integer,
          count: integer
        }
  defstruct [:state, :count]

  field(:state, 1, type: InternalApi.ServerFarm.Job.Job.State, enum: true)
  field(:count, 2, type: :int32)
end

defmodule InternalApi.ServerFarm.Job.TotalExecutionTimeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          interval: integer
        }
  defstruct [:org_id, :interval]

  field(:org_id, 1, type: :string)

  field(:interval, 2,
    type: InternalApi.ServerFarm.Job.TotalExecutionTimeRequest.Interval,
    enum: true
  )
end

defmodule InternalApi.ServerFarm.Job.TotalExecutionTimeRequest.Interval do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:LAST_DAY, 0)
end

defmodule InternalApi.ServerFarm.Job.TotalExecutionTimeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          total_duration_in_secs: integer
        }
  defstruct [:total_duration_in_secs]

  field(:total_duration_in_secs, 1, type: :int64)
end

defmodule InternalApi.ServerFarm.Job.StopRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:job_id, :requester_id]

  field(:job_id, 1, type: :string)
  field(:requester_id, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.StopResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:status]

  field(:status, 1, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.ServerFarm.Job.GetAgentPayloadRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t()
        }
  defstruct [:job_id]

  field(:job_id, 1, type: :string)
end

defmodule InternalApi.ServerFarm.Job.GetAgentPayloadResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          payload: String.t()
        }
  defstruct [:payload]

  field(:payload, 1, type: :string)
end

defmodule InternalApi.ServerFarm.Job.CanDebugRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          user_id: String.t()
        }
  defstruct [:job_id, :user_id]

  field(:job_id, 1, type: :string)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.CanDebugResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed: boolean,
          message: String.t()
        }
  defstruct [:allowed, :message]

  field(:allowed, 1, type: :bool)
  field(:message, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.CanAttachRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          user_id: String.t()
        }
  defstruct [:job_id, :user_id]

  field(:job_id, 1, type: :string)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.CanAttachResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed: boolean,
          message: String.t()
        }
  defstruct [:allowed, :message]

  field(:allowed, 1, type: :bool)
  field(:message, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          requester_id: String.t(),
          organization_id: String.t(),
          project_id: String.t(),
          branch_name: String.t(),
          commit_sha: String.t(),
          job_spec: InternalApi.ServerFarm.Job.JobSpec.t(),
          restricted_job: boolean
        }
  defstruct [
    :requester_id,
    :organization_id,
    :project_id,
    :branch_name,
    :commit_sha,
    :job_spec,
    :restricted_job
  ]

  field(:requester_id, 1, type: :string)
  field(:organization_id, 2, type: :string)
  field(:project_id, 3, type: :string)
  field(:branch_name, 4, type: :string)
  field(:commit_sha, 5, type: :string)
  field(:job_spec, 6, type: InternalApi.ServerFarm.Job.JobSpec)
  field(:restricted_job, 7, type: :bool)
end

defmodule InternalApi.ServerFarm.Job.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          job: InternalApi.ServerFarm.Job.Job.t()
        }
  defstruct [:status, :job]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:job, 2, type: InternalApi.ServerFarm.Job.Job)
end

defmodule InternalApi.ServerFarm.Job.JobSpec do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_name: String.t(),
          agent: InternalApi.ServerFarm.Job.JobSpec.Agent.t(),
          secrets: [InternalApi.ServerFarm.Job.JobSpec.Secret.t()],
          env_vars: [InternalApi.ServerFarm.Job.JobSpec.EnvVar.t()],
          files: [InternalApi.ServerFarm.Job.JobSpec.File.t()],
          commands: [String.t()],
          epilogue_always_commands: [String.t()],
          epilogue_on_pass_commands: [String.t()],
          epilogue_on_fail_commands: [String.t()],
          priority: integer,
          execution_time_limit: integer
        }
  defstruct [
    :job_name,
    :agent,
    :secrets,
    :env_vars,
    :files,
    :commands,
    :epilogue_always_commands,
    :epilogue_on_pass_commands,
    :epilogue_on_fail_commands,
    :priority,
    :execution_time_limit
  ]

  field(:job_name, 1, type: :string)
  field(:agent, 2, type: InternalApi.ServerFarm.Job.JobSpec.Agent)
  field(:secrets, 3, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.Secret)
  field(:env_vars, 4, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.EnvVar)
  field(:files, 5, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.File)
  field(:commands, 6, repeated: true, type: :string)
  field(:epilogue_always_commands, 7, repeated: true, type: :string)
  field(:epilogue_on_pass_commands, 8, repeated: true, type: :string)
  field(:epilogue_on_fail_commands, 9, repeated: true, type: :string)
  field(:priority, 10, type: :int32)
  field(:execution_time_limit, 11, type: :int32)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine: InternalApi.ServerFarm.Job.JobSpec.Agent.Machine.t(),
          containers: [InternalApi.ServerFarm.Job.JobSpec.Agent.Container.t()],
          image_pull_secrets: [InternalApi.ServerFarm.Job.JobSpec.Agent.ImagePullSecret.t()]
        }
  defstruct [:machine, :containers, :image_pull_secrets]

  field(:machine, 1, type: InternalApi.ServerFarm.Job.JobSpec.Agent.Machine)
  field(:containers, 2, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.Agent.Container)

  field(:image_pull_secrets, 3,
    repeated: true,
    type: InternalApi.ServerFarm.Job.JobSpec.Agent.ImagePullSecret
  )
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Agent.Machine do
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

defmodule InternalApi.ServerFarm.Job.JobSpec.Agent.Container do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          image: String.t(),
          command: String.t(),
          env_vars: [InternalApi.ServerFarm.Job.JobSpec.EnvVar.t()],
          secrets: [InternalApi.ServerFarm.Job.JobSpec.Secret.t()]
        }
  defstruct [:name, :image, :command, :env_vars, :secrets]

  field(:name, 1, type: :string)
  field(:image, 2, type: :string)
  field(:command, 3, type: :string)
  field(:env_vars, 4, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.EnvVar)
  field(:secrets, 5, repeated: true, type: InternalApi.ServerFarm.Job.JobSpec.Secret)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Agent.ImagePullSecret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t()
        }
  defstruct [:name]

  field(:name, 1, type: :string)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.Secret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t()
        }
  defstruct [:name]

  field(:name, 1, type: :string)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.EnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t()
        }
  defstruct [:name, :value]

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.JobSpec.File do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          path: String.t(),
          content: String.t()
        }
  defstruct [:path, :content]

  field(:path, 1, type: :string)
  field(:content, 2, type: :string)
end

defmodule InternalApi.ServerFarm.Job.JobDeleted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          organization_id: String.t(),
          deleted_at: Google.Protobuf.Timestamp.t(),
          artifact_store_id: String.t(),
          project_id: String.t()
        }
  defstruct [:job_id, :organization_id, :deleted_at, :artifact_store_id, :project_id]

  field(:job_id, 1, type: :string)
  field(:organization_id, 2, type: :string)
  field(:deleted_at, 3, type: Google.Protobuf.Timestamp)
  field(:artifact_store_id, 4, type: :string)
  field(:project_id, 5, type: :string)
end

defmodule InternalApi.ServerFarm.Job.DebugSessionType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:JOB, 0)
  field(:PROJECT, 1)
end

defmodule InternalApi.ServerFarm.Job.JobService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.ServerFarm.Job.JobService"

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
