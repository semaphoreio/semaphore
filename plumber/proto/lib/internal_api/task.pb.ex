defmodule InternalApi.Task.Task do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          state: integer,
          result: integer,
          jobs: [InternalApi.Task.Task.Job.t()],
          ppl_id: String.t(),
          wf_id: String.t(),
          hook_id: String.t(),
          request_token: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          finished_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :id,
    :state,
    :result,
    :jobs,
    :ppl_id,
    :wf_id,
    :hook_id,
    :request_token,
    :created_at,
    :finished_at
  ]

  field(:id, 1, type: :string)
  field(:state, 2, type: InternalApi.Task.Task.State, enum: true)
  field(:result, 3, type: InternalApi.Task.Task.Result, enum: true)
  field(:jobs, 4, repeated: true, type: InternalApi.Task.Task.Job)
  field(:ppl_id, 5, type: :string)
  field(:wf_id, 6, type: :string)
  field(:hook_id, 10, type: :string)
  field(:request_token, 7, type: :string)
  field(:created_at, 8, type: Google.Protobuf.Timestamp)
  field(:finished_at, 9, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Task.Task.Job do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          state: integer,
          result: integer,
          name: String.t(),
          index: integer,
          created_at: Google.Protobuf.Timestamp.t(),
          enqueued_at: Google.Protobuf.Timestamp.t(),
          scheduled_at: Google.Protobuf.Timestamp.t(),
          started_at: Google.Protobuf.Timestamp.t(),
          finished_at: Google.Protobuf.Timestamp.t(),
          priority: integer
        }
  defstruct [
    :id,
    :state,
    :result,
    :name,
    :index,
    :created_at,
    :enqueued_at,
    :scheduled_at,
    :started_at,
    :finished_at,
    :priority
  ]

  field(:id, 1, type: :string)
  field(:state, 2, type: InternalApi.Task.Task.Job.State, enum: true)
  field(:result, 3, type: InternalApi.Task.Task.Job.Result, enum: true)
  field(:name, 4, type: :string)
  field(:index, 5, type: :int32)
  field(:created_at, 7, type: Google.Protobuf.Timestamp)
  field(:enqueued_at, 8, type: Google.Protobuf.Timestamp)
  field(:scheduled_at, 9, type: Google.Protobuf.Timestamp)
  field(:started_at, 10, type: Google.Protobuf.Timestamp)
  field(:finished_at, 11, type: Google.Protobuf.Timestamp)
  field(:priority, 12, type: :int32)
end

defmodule InternalApi.Task.Task.Job.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ENQUEUED, 0)
  field(:RUNNING, 1)
  field(:STOPPING, 2)
  field(:FINISHED, 3)
end

defmodule InternalApi.Task.Task.Job.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.Task.Task.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:RUNNING, 0)
  field(:STOPPING, 1)
  field(:FINISHED, 2)
end

defmodule InternalApi.Task.Task.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.Task.ScheduleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          jobs: [InternalApi.Task.ScheduleRequest.Job.t()],
          request_token: String.t(),
          ppl_id: String.t(),
          wf_id: String.t(),
          hook_id: String.t(),
          project_id: String.t(),
          repository_id: String.t(),
          deployment_target_id: String.t(),
          org_id: String.t(),
          fail_fast: integer
        }
  defstruct [
    :jobs,
    :request_token,
    :ppl_id,
    :wf_id,
    :hook_id,
    :project_id,
    :repository_id,
    :deployment_target_id,
    :org_id,
    :fail_fast
  ]

  field(:jobs, 1, repeated: true, type: InternalApi.Task.ScheduleRequest.Job)
  field(:request_token, 2, type: :string)
  field(:ppl_id, 3, type: :string)
  field(:wf_id, 4, type: :string)
  field(:hook_id, 8, type: :string)
  field(:project_id, 5, type: :string)
  field(:repository_id, 9, type: :string)
  field(:deployment_target_id, 10, type: :string)
  field(:org_id, 6, type: :string)
  field(:fail_fast, 7, type: InternalApi.Task.ScheduleRequest.FailFast, enum: true)
end

defmodule InternalApi.Task.ScheduleRequest.Job do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          agent: InternalApi.Task.ScheduleRequest.Job.Agent.t(),
          env_vars: [InternalApi.Task.ScheduleRequest.Job.EnvVar.t()],
          secrets: [InternalApi.Task.ScheduleRequest.Job.Secret.t()],
          prologue_commands: [String.t()],
          commands: [String.t()],
          epilogue_always_cmds: [String.t()],
          epilogue_on_pass_cmds: [String.t()],
          epilogue_on_fail_cmds: [String.t()],
          execution_time_limit: integer,
          priority: integer
        }
  defstruct [
    :name,
    :agent,
    :env_vars,
    :secrets,
    :prologue_commands,
    :commands,
    :epilogue_always_cmds,
    :epilogue_on_pass_cmds,
    :epilogue_on_fail_cmds,
    :execution_time_limit,
    :priority
  ]

  field(:name, 1, type: :string)
  field(:agent, 2, type: InternalApi.Task.ScheduleRequest.Job.Agent)
  field(:env_vars, 3, repeated: true, type: InternalApi.Task.ScheduleRequest.Job.EnvVar)
  field(:secrets, 4, repeated: true, type: InternalApi.Task.ScheduleRequest.Job.Secret)
  field(:prologue_commands, 5, repeated: true, type: :string)
  field(:commands, 6, repeated: true, type: :string)
  field(:epilogue_always_cmds, 8, repeated: true, type: :string)
  field(:epilogue_on_pass_cmds, 9, repeated: true, type: :string)
  field(:epilogue_on_fail_cmds, 10, repeated: true, type: :string)
  field(:execution_time_limit, 11, type: :int32)
  field(:priority, 12, type: :int32)
end

defmodule InternalApi.Task.ScheduleRequest.Job.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine: InternalApi.Task.ScheduleRequest.Job.Agent.Machine.t(),
          containers: [InternalApi.Task.ScheduleRequest.Job.Agent.Container.t()],
          image_pull_secrets: [InternalApi.Task.ScheduleRequest.Job.Agent.ImagePullSecret.t()]
        }
  defstruct [:machine, :containers, :image_pull_secrets]

  field(:machine, 1, type: InternalApi.Task.ScheduleRequest.Job.Agent.Machine)

  field(:containers, 2,
    repeated: true,
    type: InternalApi.Task.ScheduleRequest.Job.Agent.Container
  )

  field(:image_pull_secrets, 3,
    repeated: true,
    type: InternalApi.Task.ScheduleRequest.Job.Agent.ImagePullSecret
  )
end

defmodule InternalApi.Task.ScheduleRequest.Job.Agent.Machine do
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

defmodule InternalApi.Task.ScheduleRequest.Job.Agent.Container do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          image: String.t(),
          command: String.t(),
          env_vars: [InternalApi.Task.ScheduleRequest.Job.EnvVar.t()],
          secrets: [InternalApi.Task.ScheduleRequest.Job.Secret.t()],
          entrypoint: String.t(),
          user: String.t()
        }
  defstruct [:name, :image, :command, :env_vars, :secrets, :entrypoint, :user]

  field(:name, 1, type: :string)
  field(:image, 2, type: :string)
  field(:command, 3, type: :string)
  field(:env_vars, 4, repeated: true, type: InternalApi.Task.ScheduleRequest.Job.EnvVar)
  field(:secrets, 5, repeated: true, type: InternalApi.Task.ScheduleRequest.Job.Secret)
  field(:entrypoint, 6, type: :string)
  field(:user, 7, type: :string)
end

defmodule InternalApi.Task.ScheduleRequest.Job.Agent.ImagePullSecret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t()
        }
  defstruct [:name]

  field(:name, 1, type: :string)
end

defmodule InternalApi.Task.ScheduleRequest.Job.EnvVar do
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

defmodule InternalApi.Task.ScheduleRequest.Job.Secret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t()
        }
  defstruct [:name]

  field(:name, 1, type: :string)
end

defmodule InternalApi.Task.ScheduleRequest.FailFast do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NONE, 0)
  field(:STOP, 1)
  field(:CANCEL, 2)
end

defmodule InternalApi.Task.ScheduleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          task: InternalApi.Task.Task.t()
        }
  defstruct [:task]

  field(:task, 1, type: InternalApi.Task.Task)
end

defmodule InternalApi.Task.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          task_id: String.t()
        }
  defstruct [:task_id]

  field(:task_id, 1, type: :string)
end

defmodule InternalApi.Task.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          task: InternalApi.Task.Task.t()
        }
  defstruct [:task]

  field(:task, 1, type: InternalApi.Task.Task)
end

defmodule InternalApi.Task.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          task_ids: [String.t()]
        }
  defstruct [:task_ids]

  field(:task_ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.Task.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          tasks: [InternalApi.Task.Task.t()]
        }
  defstruct [:tasks]

  field(:tasks, 1, repeated: true, type: InternalApi.Task.Task)
end

defmodule InternalApi.Task.TerminateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          task_id: String.t()
        }
  defstruct [:task_id]

  field(:task_id, 1, type: :string)
end

defmodule InternalApi.Task.TerminateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          message: String.t()
        }
  defstruct [:message]

  field(:message, 1, type: :string)
end

defmodule InternalApi.Task.TaskStarted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          task_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:task_id, :timestamp]

  field(:task_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Task.TaskFinished do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          task_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:task_id, :timestamp]

  field(:task_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Task.TaskService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Task.TaskService"

  rpc(:Schedule, InternalApi.Task.ScheduleRequest, InternalApi.Task.ScheduleResponse)
  rpc(:Describe, InternalApi.Task.DescribeRequest, InternalApi.Task.DescribeResponse)
  rpc(:DescribeMany, InternalApi.Task.DescribeManyRequest, InternalApi.Task.DescribeManyResponse)
  rpc(:Terminate, InternalApi.Task.TerminateRequest, InternalApi.Task.TerminateResponse)
end

defmodule InternalApi.Task.TaskService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Task.TaskService.Service
end
