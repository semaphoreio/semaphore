defmodule Semaphore.Jobs.V1alpha.Job.Status.Result do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:NONE, 0)
  field(:PASSED, 1)
  field(:FAILED, 2)
  field(:STOPPED, 3)
end

defmodule Semaphore.Jobs.V1alpha.Job.Status.State do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:PENDING, 0)
  field(:QUEUED, 1)
  field(:RUNNING, 2)
  field(:FINISHED, 3)
end

defmodule Semaphore.Jobs.V1alpha.ListJobsRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:BY_CREATE_TIME_DESC, 0)
end

defmodule Semaphore.Jobs.V1alpha.Job.Metadata do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:create_time, 3, type: :int64, json_name: "createTime")
  field(:update_time, 4, type: :int64, json_name: "updateTime")
  field(:start_time, 5, type: :int64, json_name: "startTime")
  field(:finish_time, 6, type: :int64, json_name: "finishTime")
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: :string)
  field(:os_image, 2, type: :string, json_name: "osImage")
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:image, 2, type: :string)
  field(:command, 3, type: :string)

  field(:env_vars, 4,
    repeated: true,
    type: Semaphore.Jobs.V1alpha.Job.Spec.EnvVar,
    json_name: "envVars"
  )

  field(:secrets, 5, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.Secret)
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Agent.ImagePullSecret do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Agent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:machine, 1, type: Semaphore.Jobs.V1alpha.Job.Spec.Agent.Machine)
  field(:containers, 2, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.Agent.Container)

  field(:image_pull_secrets, 3,
    repeated: true,
    type: Semaphore.Jobs.V1alpha.Job.Spec.Agent.ImagePullSecret,
    json_name: "imagePullSecrets"
  )
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.Secret do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.EnvVar do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec.File do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:path, 1, type: :string)
  field(:content, 2, type: :string)
end

defmodule Semaphore.Jobs.V1alpha.Job.Spec do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:agent, 2, type: Semaphore.Jobs.V1alpha.Job.Spec.Agent)
  field(:secrets, 3, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.Secret)

  field(:env_vars, 4,
    repeated: true,
    type: Semaphore.Jobs.V1alpha.Job.Spec.EnvVar,
    json_name: "envVars"
  )

  field(:files, 5, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Spec.File)
  field(:commands, 6, repeated: true, type: :string)
  field(:epilogue_commands, 7, repeated: true, type: :string, json_name: "epilogueCommands")

  field(:epilogue_always_commands, 8,
    repeated: true,
    type: :string,
    json_name: "epilogueAlwaysCommands"
  )

  field(:epilogue_on_pass_commands, 9,
    repeated: true,
    type: :string,
    json_name: "epilogueOnPassCommands"
  )

  field(:epilogue_on_fail_commands, 10,
    repeated: true,
    type: :string,
    json_name: "epilogueOnFailCommands"
  )
end

defmodule Semaphore.Jobs.V1alpha.Job.Status.Agent.Port do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:number, 2, type: :int32)
end

defmodule Semaphore.Jobs.V1alpha.Job.Status.Agent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:ip, 1, type: :string)
  field(:ports, 2, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Status.Agent.Port)
  field(:name, 3, type: :string)
end

defmodule Semaphore.Jobs.V1alpha.Job.Status do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:result, 1, type: Semaphore.Jobs.V1alpha.Job.Status.Result, enum: true)
  field(:state, 2, type: Semaphore.Jobs.V1alpha.Job.Status.State, enum: true)
  field(:agent, 3, type: Semaphore.Jobs.V1alpha.Job.Status.Agent)
end

defmodule Semaphore.Jobs.V1alpha.Job do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:metadata, 1, type: Semaphore.Jobs.V1alpha.Job.Metadata)
  field(:spec, 2, type: Semaphore.Jobs.V1alpha.Job.Spec)
  field(:status, 3, type: Semaphore.Jobs.V1alpha.Job.Status)
end

defmodule Semaphore.Jobs.V1alpha.ListJobsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:page_size, 1, type: :int32, json_name: "pageSize")
  field(:page_token, 2, type: :string, json_name: "pageToken")
  field(:order, 3, type: Semaphore.Jobs.V1alpha.ListJobsRequest.Order, enum: true)
  field(:states, 4, repeated: true, type: Semaphore.Jobs.V1alpha.Job.Status.State, enum: true)
end

defmodule Semaphore.Jobs.V1alpha.ListJobsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:jobs, 1, repeated: true, type: Semaphore.Jobs.V1alpha.Job)
  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
end

defmodule Semaphore.Jobs.V1alpha.GetJobRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
end

defmodule Semaphore.Jobs.V1alpha.StopJobRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
end

defmodule Semaphore.Jobs.V1alpha.Empty do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
end

defmodule Semaphore.Jobs.V1alpha.JobDebugSSHKey do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:key, 1, type: :string)
end

defmodule Semaphore.Jobs.V1alpha.CreateDebugJobRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
  field(:duration, 2, type: :int32)
end

defmodule Semaphore.Jobs.V1alpha.CreateDebugProjectRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id_or_name, 1, type: :string, json_name: "projectIdOrName")
  field(:duration, 2, type: :int32)
  field(:machine_type, 3, type: :string, json_name: "machineType")
end

defmodule Semaphore.Jobs.V1alpha.JobsApi.Service do
  @moduledoc false

  use GRPC.Service, name: "semaphore.jobs.v1alpha.JobsApi", protoc_gen_elixir_version: "0.13.0"

  rpc(:ListJobs, Semaphore.Jobs.V1alpha.ListJobsRequest, Semaphore.Jobs.V1alpha.ListJobsResponse)

  rpc(:GetJob, Semaphore.Jobs.V1alpha.GetJobRequest, Semaphore.Jobs.V1alpha.Job)

  rpc(
    :GetJobDebugSSHKey,
    Semaphore.Jobs.V1alpha.GetJobDebugSSHKeyRequest,
    Semaphore.Jobs.V1alpha.JobDebugSSHKey
  )

  rpc(:CreateJob, Semaphore.Jobs.V1alpha.Job, Semaphore.Jobs.V1alpha.Job)

  rpc(:CreateDebugJob, Semaphore.Jobs.V1alpha.CreateDebugJobRequest, Semaphore.Jobs.V1alpha.Job)

  rpc(
    :CreateDebugProject,
    Semaphore.Jobs.V1alpha.CreateDebugProjectRequest,
    Semaphore.Jobs.V1alpha.Job
  )

  rpc(:StopJob, Semaphore.Jobs.V1alpha.StopJobRequest, Semaphore.Jobs.V1alpha.Empty)
end

defmodule Semaphore.Jobs.V1alpha.JobsApi.Stub do
  @moduledoc false

  use GRPC.Stub, service: Semaphore.Jobs.V1alpha.JobsApi.Service
end
