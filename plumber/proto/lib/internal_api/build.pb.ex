defmodule InternalApi.Build.ScheduleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          build: InternalApi.Build.Build.t(),
          build_request_id: String.t(),
          ppl_id: String.t(),
          hook_id: String.t(),
          wf_id: String.t()
        }
  defstruct [:build, :build_request_id, :ppl_id, :hook_id, :wf_id]

  field(:build, 1, type: InternalApi.Build.Build)
  field(:build_request_id, 5, type: :string)
  field(:ppl_id, 6, type: :string)
  field(:hook_id, 7, type: :string)
  field(:wf_id, 8, type: :string)
end

defmodule InternalApi.Build.Build do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          jobs: [InternalApi.Build.Job.t()],
          boosters: [InternalApi.Build.Booster.t()]
        }
  defstruct [:jobs, :boosters]

  field(:jobs, 1, repeated: true, type: InternalApi.Build.Job)
  field(:boosters, 2, repeated: true, type: InternalApi.Build.Booster)
end

defmodule InternalApi.Build.Job do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          semaphore_image: String.t(),
          agent: InternalApi.Build.Agent.t(),
          ppl_env_variables: [InternalApi.Build.EnvVariable.t()],
          env_variables: [InternalApi.Build.EnvVariable.t()],
          secrets: [InternalApi.Build.Secret.t()],
          ppl_commands: [String.t()],
          prologue_commands: [String.t()],
          commands: [String.t()],
          epilogue_commands: [String.t()]
        }
  defstruct [
    :name,
    :semaphore_image,
    :agent,
    :ppl_env_variables,
    :env_variables,
    :secrets,
    :ppl_commands,
    :prologue_commands,
    :commands,
    :epilogue_commands
  ]

  field(:name, 2, type: :string)
  field(:semaphore_image, 8, type: :string)
  field(:agent, 12, type: InternalApi.Build.Agent)
  field(:ppl_env_variables, 10, repeated: true, type: InternalApi.Build.EnvVariable)
  field(:env_variables, 3, repeated: true, type: InternalApi.Build.EnvVariable)
  field(:secrets, 11, repeated: true, type: InternalApi.Build.Secret)
  field(:ppl_commands, 9, repeated: true, type: :string)
  field(:prologue_commands, 5, repeated: true, type: :string)
  field(:commands, 1, repeated: true, type: :string)
  field(:epilogue_commands, 6, repeated: true, type: :string)
end

defmodule InternalApi.Build.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine: InternalApi.Build.Agent.Machine.t()
        }
  defstruct [:machine]

  field(:machine, 1, type: InternalApi.Build.Agent.Machine)
end

defmodule InternalApi.Build.Agent.Machine do
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

defmodule InternalApi.Build.EnvVariable do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }
  defstruct [:key, :value]

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.Build.Booster do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          job_count: integer,
          type: integer,
          env_variables: [InternalApi.Build.EnvVariable.t()],
          prologue_commands: [String.t()],
          epilogue_commands: [String.t()],
          secrets: [InternalApi.Build.Secret.t()],
          semaphore_image: String.t(),
          ppl_commands: [String.t()],
          ppl_env_variables: [InternalApi.Build.EnvVariable.t()]
        }
  defstruct [
    :name,
    :job_count,
    :type,
    :env_variables,
    :prologue_commands,
    :epilogue_commands,
    :secrets,
    :semaphore_image,
    :ppl_commands,
    :ppl_env_variables
  ]

  field(:name, 1, type: :string)
  field(:job_count, 2, type: :int32)
  field(:type, 3, type: InternalApi.Build.Booster.Type, enum: true)
  field(:env_variables, 4, repeated: true, type: InternalApi.Build.EnvVariable)
  field(:prologue_commands, 6, repeated: true, type: :string)
  field(:epilogue_commands, 7, repeated: true, type: :string)
  field(:secrets, 12, repeated: true, type: InternalApi.Build.Secret)
  field(:semaphore_image, 9, type: :string)
  field(:ppl_commands, 10, repeated: true, type: :string)
  field(:ppl_env_variables, 11, repeated: true, type: InternalApi.Build.EnvVariable)
end

defmodule InternalApi.Build.Booster.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:RSPEC, 0)
  field(:CUCUMBER, 1)
end

defmodule InternalApi.Build.Secret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          env_var_names: [String.t()],
          config_file_paths: [String.t()]
        }
  defstruct [:name, :env_var_names, :config_file_paths]

  field(:name, 1, type: :string)
  field(:env_var_names, 2, repeated: true, type: :string)
  field(:config_file_paths, 3, repeated: true, type: :string)
end

defmodule InternalApi.Build.ScheduleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Build.ResponseStatus.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:response_status, :status]

  field(:response_status, 2, type: InternalApi.Build.ResponseStatus)
  field(:status, 3, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Build.ResponseStatus do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: integer,
          message: String.t()
        }
  defstruct [:code, :message]

  field(:code, 1, type: InternalApi.Build.ResponseStatus.ResponseCode, enum: true)
  field(:message, 2, type: :string)
end

defmodule InternalApi.Build.ResponseStatus.ResponseCode do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:OK, 0)
  field(:BAD_PARAM, 2)
end

defmodule InternalApi.Build.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          build_request_id: String.t()
        }
  defstruct [:build_request_id]

  field(:build_request_id, 2, type: :string)
end

defmodule InternalApi.Build.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          build_request_ids: [String.t()]
        }
  defstruct [:build_request_ids]

  field(:build_request_ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.Build.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          build_status: InternalApi.Build.ExecutionStatus.t(),
          response_status: InternalApi.Build.ResponseStatus.t(),
          build: InternalApi.Build.BuildDescription.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:build_status, :response_status, :build, :status]

  field(:build_status, 1, type: InternalApi.Build.ExecutionStatus)
  field(:response_status, 3, type: InternalApi.Build.ResponseStatus)
  field(:build, 4, type: InternalApi.Build.BuildDescription)
  field(:status, 5, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Build.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Build.ResponseStatus.t(),
          builds: [InternalApi.Build.BuildDescription.t()],
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:response_status, :builds, :status]

  field(:response_status, 1, type: InternalApi.Build.ResponseStatus)
  field(:builds, 2, repeated: true, type: InternalApi.Build.BuildDescription)
  field(:status, 3, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Build.BuildDescription do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          build_request_id: String.t(),
          status: integer,
          result: integer,
          jobs: [InternalApi.Build.BuildDescription.Job.t()]
        }
  defstruct [:build_request_id, :status, :result, :jobs]

  field(:build_request_id, 1, type: :string)
  field(:status, 2, type: InternalApi.Build.BuildDescription.Status, enum: true)
  field(:result, 3, type: InternalApi.Build.BuildDescription.Result, enum: true)
  field(:jobs, 4, repeated: true, type: InternalApi.Build.BuildDescription.Job)
end

defmodule InternalApi.Build.BuildDescription.Job do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          status: integer,
          result: integer,
          name: String.t(),
          index: integer
        }
  defstruct [:job_id, :status, :result, :name, :index]

  field(:job_id, 1, type: :string)
  field(:status, 2, type: InternalApi.Build.BuildDescription.Job.Status, enum: true)
  field(:result, 3, type: InternalApi.Build.BuildDescription.Job.Result, enum: true)
  field(:name, 4, type: :string)
  field(:index, 5, type: :int32)
end

defmodule InternalApi.Build.BuildDescription.Job.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ENQUEUED, 0)
  field(:RUNNING, 1)
  field(:STOPPING, 2)
  field(:FINISHED, 3)
end

defmodule InternalApi.Build.BuildDescription.Job.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.Build.BuildDescription.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ENQUEUED, 0)
  field(:RUNNING, 1)
  field(:STOPPING, 2)
  field(:FINISHED, 3)
  field(:DELETED, 4)
end

defmodule InternalApi.Build.BuildDescription.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.Build.ExecutionStatus do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: integer,
          result: integer,
          name: String.t()
        }
  defstruct [:status, :result, :name]

  field(:status, 1, type: InternalApi.Build.ExecutionStatus.Status, enum: true)
  field(:result, 2, type: InternalApi.Build.ExecutionStatus.Result, enum: true)
  field(:name, 3, type: :string)
end

defmodule InternalApi.Build.ExecutionStatus.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ENQUEUED, 0)
  field(:RUNNING, 1)
  field(:STOPPING, 2)
  field(:FINISHED, 3)
  field(:DELETED, 4)
end

defmodule InternalApi.Build.ExecutionStatus.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.Build.VersionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Build.VersionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          version: String.t()
        }
  defstruct [:version]

  field(:version, 1, type: :string)
end

defmodule InternalApi.Build.TerminateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          build_request_id: String.t()
        }
  defstruct [:build_request_id]

  field(:build_request_id, 1, type: :string)
end

defmodule InternalApi.Build.TerminateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Build.ResponseStatus.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:response_status, :status]

  field(:response_status, 1, type: InternalApi.Build.ResponseStatus)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Build.BuildStarted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          build_request_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:build_request_id, :timestamp]

  field(:build_request_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Build.BuildFinished do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          build_request_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:build_request_id, :timestamp]

  field(:build_request_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Build.BuildService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Build.BuildService"

  rpc(:Schedule, InternalApi.Build.ScheduleRequest, InternalApi.Build.ScheduleResponse)
  rpc(:Describe, InternalApi.Build.DescribeRequest, InternalApi.Build.DescribeResponse)

  rpc(
    :DescribeMany,
    InternalApi.Build.DescribeManyRequest,
    InternalApi.Build.DescribeManyResponse
  )

  rpc(:Version, InternalApi.Build.VersionRequest, InternalApi.Build.VersionResponse)
  rpc(:Terminate, InternalApi.Build.TerminateRequest, InternalApi.Build.TerminateResponse)
end

defmodule InternalApi.Build.BuildService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Build.BuildService.Service
end
