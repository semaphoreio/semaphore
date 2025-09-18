defmodule Semaphore.Jobs.V1alpha.Job do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: Semaphore.Jobs.V1alpha.Job.Metadata.t(),
          spec: Semaphore.Jobs.V1alpha.Job.Spec.t(),
          status: Semaphore.Jobs.V1alpha.Job.Status.t()
        }
  defstruct [:metadata, :spec, :status]

  field :metadata, 1, type: Semaphore.Jobs.V1alpha.Job.Metadata
  field :spec, 2, type: Semaphore.Jobs.V1alpha.Job.Spec
  field :status, 3, type: Semaphore.Jobs.V1alpha.Job.Status
end

defmodule Semaphore.Jobs.V1alpha.Job.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          create_time: integer,
          update_time: integer,
          start_time: integer,
          finish_time: integer
        }
  defstruct [:name, :id, :create_time, :update_time, :start_time, :finish_time]

  field :name, 1, type: :string
  field :id, 2, type: :string
  field :create_time, 3, type: :int64
  field :update_time, 4, type: :int64
  field :start_time, 5, type: :int64
  field :finish_time, 6, type: :int64
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          agent: Semaphore.Jobs.V1alpha.Job.Spec.Agent.t(),
          secrets: [Semaphore.Jobs.V1alpha.Job.Spec.Secret.t()],
          env_vars: [Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.t()],
          files: [Semaphore.Jobs.V1alpha.Job.Spec.File.t()],
          commands: [String.t()],
          epilogue_commands: [String.t()],
          epilogue_always_commands: [String.t()],
          epilogue_on_pass_commands: [String.t()],
          epilogue_on_fail_commands: [String.t()]
        }
  defstruct [
    :project_id,
    :agent,
    :secrets,
    :env_vars,
    :files,
    :commands,
    :epilogue_commands,
    :epilogue_always_commands,
    :epilogue_on_pass_commands,
    :epilogue_on_fail_commands
  ]

  field :project_id, 1, type: :string
  field :agent, 2, type: Semaphore.Jobs.V1alpha.Job.Spec.Agent
  field :secrets, 3, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.Secret
  field :env_vars, 4, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.EnvVar
  field :files, 5, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.File
  field :commands, 6, repeated: true, type: :string
  field :epilogue_commands, 7, repeated: true, type: :string
  field :epilogue_always_commands, 8, repeated: true, type: :string
  field :epilogue_on_pass_commands, 9, repeated: true, type: :string
  field :epilogue_on_fail_commands, 10, repeated: true, type: :string
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine: Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine.t(),
          containers: [Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container.t()],
          image_pull_secrets: [Semaphore.Jobs.V1alpha.Job.Spec.Agent.ImagePullSecret.t()]
        }
  defstruct [:machine, :containers, :image_pull_secrets]

  field :machine, 1, type: Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine
  field :containers, 2, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container

  field :image_pull_secrets, 3,
    repeated: true,
    type: Semaphore.Jobs.V1alpha.Job.Spec.Agent.ImagePullSecret
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: String.t(),
          os_image: String.t()
        }
  defstruct [:type, :os_image]

  field :type, 1, type: :string
  field :os_image, 2, type: :string
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          image: String.t(),
          command: String.t(),
          env_vars: [Semaphore.Jobs.V1alpha.Job.Spec.EnvVar.t()],
          secrets: [Semaphore.Jobs.V1alpha.Job.Spec.Secret.t()]
        }
  defstruct [:name, :image, :command, :env_vars, :secrets]

  field :name, 1, type: :string
  field :image, 2, type: :string
  field :command, 3, type: :string
  field :env_vars, 4, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.EnvVar
  field :secrets, 5, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.Secret
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Agent.ImagePullSecret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t()
        }
  defstruct [:name]

  field :name, 1, type: :string
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Secret do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t()
        }
  defstruct [:name]

  field :name, 1, type: :string
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.EnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t()
        }
  defstruct [:name, :value]

  field :name, 1, type: :string
  field :value, 2, type: :string
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.File do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          path: String.t(),
          content: String.t()
        }
  defstruct [:path, :content]

  field :path, 1, type: :string
  field :content, 2, type: :string
end

defmodule Semaphore.Jobs.V1alpha.Job.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          result: integer,
          state: integer,
          agent: Semaphore.Jobs.V1alpha.Job.Status.Agent.t()
        }
  defstruct [:result, :state, :agent]

  field :result, 1, type: Semaphore.Jobs.V1alpha.Job.Status.Result, enum: true
  field :state, 2, type: Semaphore.Jobs.V1alpha.Job.Status.State, enum: true
  field :agent, 3, type: Semaphore.Jobs.V1alpha.Job.Status.Agent
end

defmodule Semaphore.Jobs.V1alpha.Job.Status.Agent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ip: String.t(),
          ports: [Semaphore.Jobs.V1alpha.Job.Status.Agent.Port.t()],
          name: String.t()
        }
  defstruct [:ip, :ports, :name]

  field :ip, 1, type: :string
  field :ports, 2, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Status.Agent.Port
  field :name, 3, type: :string
end

defmodule Semaphore.Jobs.V1alpha.Job.Status.Agent.Port do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          number: integer
        }
  defstruct [:name, :number]

  field :name, 1, type: :string
  field :number, 2, type: :int32
end

defmodule Semaphore.Jobs.V1alpha.Job.Status.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :NONE, 0
  field :PASSED, 1
  field :FAILED, 2
  field :STOPPED, 3
end

defmodule Semaphore.Jobs.V1alpha.Job.Status.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :PENDING, 0
  field :QUEUED, 1
  field :RUNNING, 2
  field :FINISHED, 3
end

defmodule Semaphore.Jobs.V1alpha.ListJobsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: integer,
          states: [integer]
        }
  defstruct [:page_size, :page_token, :order, :states]

  field :page_size, 1, type: :int32
  field :page_token, 2, type: :string
  field :order, 3, type: Semaphore.Jobs.V1alpha.ListJobsRequest.Order, enum: true
  field :states, 4, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Status.State, enum: true
end

defmodule Semaphore.Jobs.V1alpha.ListJobsRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :BY_CREATE_TIME_DESC, 0
end

defmodule Semaphore.Jobs.V1alpha.ListJobsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          jobs: [Semaphore.Jobs.V1alpha.Job.t()],
          next_page_token: String.t()
        }
  defstruct [:jobs, :next_page_token]

  field :jobs, 1, repeated: true, type: Semaphore.Jobs.V1alpha.Job
  field :next_page_token, 2, type: :string
end

defmodule Semaphore.Jobs.V1alpha.GetJobRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t()
        }
  defstruct [:job_id]

  field :job_id, 1, type: :string
end

defmodule Semaphore.Jobs.V1alpha.StopJobRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t()
        }
  defstruct [:job_id]

  field :job_id, 1, type: :string
end

defmodule Semaphore.Jobs.V1alpha.Empty do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t()
        }
  defstruct [:job_id]

  field :job_id, 1, type: :string
end

defmodule Semaphore.Jobs.V1alpha.JobDebugSSHKey do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t()
        }
  defstruct [:key]

  field :key, 1, type: :string
end

defmodule Semaphore.Jobs.V1alpha.CreateDebugJobRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          duration: integer
        }
  defstruct [:job_id, :duration]

  field :job_id, 1, type: :string
  field :duration, 2, type: :int32
end

defmodule Semaphore.Jobs.V1alpha.CreateDebugProjectRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id_or_name: String.t(),
          duration: integer,
          machine_type: String.t()
        }
  defstruct [:project_id_or_name, :duration, :machine_type]

  field :project_id_or_name, 1, type: :string
  field :duration, 2, type: :int32
  field :machine_type, 3, type: :string
end

defmodule Semaphore.Jobs.V1alpha.JobsApi.Service do
  @moduledoc false
  use GRPC.Service, name: "semaphore.jobs.v1alpha.JobsApi"

  rpc :ListJobs, Semaphore.Jobs.V1alpha.ListJobsRequest, Semaphore.Jobs.V1alpha.ListJobsResponse
  rpc :GetJob, Semaphore.Jobs.V1alpha.GetJobRequest, Semaphore.Jobs.V1alpha.Job

  rpc :GetJobDebugSSHKey,
      Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest,
      Semaphore.Jobs.V1alpha.JobDebugSSHKey

  rpc :CreateJob, Semaphore.Jobs.V1alpha.Job, Semaphore.Jobs.V1alpha.Job
  rpc :CreateDebugJob, Semaphore.Jobs.V1alpha.CreateDebugJobRequest, Semaphore.Jobs.V1alpha.Job

  rpc :CreateDebugProject,
      Semaphore.Jobs.V1alpha.CreateDebugProjectRequest,
      Semaphore.Jobs.V1alpha.Job

  rpc :StopJob, Semaphore.Jobs.V1alpha.StopJobRequest, Semaphore.Jobs.V1alpha.Empty
end

defmodule Semaphore.Jobs.V1alpha.JobsApi.Stub do
  @moduledoc false
  use GRPC.Stub, service: Semaphore.Jobs.V1alpha.JobsApi.Service
end
