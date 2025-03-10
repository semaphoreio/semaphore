defmodule InternalApi.Task.Task.State do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:RUNNING, 0)
  field(:STOPPING, 1)
  field(:FINISHED, 2)
end

defmodule InternalApi.Task.Task.Result do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.Task.Task.Job.State do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:ENQUEUED, 0)
  field(:RUNNING, 1)
  field(:STOPPING, 2)
  field(:FINISHED, 3)
end

defmodule InternalApi.Task.Task.Job.Result do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:PASSED, 0)
  field(:FAILED, 1)
  field(:STOPPED, 2)
end

defmodule InternalApi.Task.ScheduleRequest.FailFast do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:NONE, 0)
  field(:STOP, 1)
  field(:CANCEL, 2)
end

defmodule InternalApi.Task.Task.Job do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:state, 2, type: InternalApi.Task.Task.Job.State, enum: true)
  field(:result, 3, type: InternalApi.Task.Task.Job.Result, enum: true)
  field(:name, 4, type: :string)
  field(:index, 5, type: :int32)
  field(:created_at, 7, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:enqueued_at, 8, type: Google.Protobuf.Timestamp, json_name: "enqueuedAt")
  field(:scheduled_at, 9, type: Google.Protobuf.Timestamp, json_name: "scheduledAt")
  field(:started_at, 10, type: Google.Protobuf.Timestamp, json_name: "startedAt")
  field(:finished_at, 11, type: Google.Protobuf.Timestamp, json_name: "finishedAt")
  field(:priority, 12, type: :int32)
end

defmodule InternalApi.Task.Task do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:state, 2, type: InternalApi.Task.Task.State, enum: true)
  field(:result, 3, type: InternalApi.Task.Task.Result, enum: true)
  field(:jobs, 4, repeated: true, type: InternalApi.Task.Task.Job)
  field(:ppl_id, 5, type: :string, json_name: "pplId")
  field(:wf_id, 6, type: :string, json_name: "wfId")
  field(:hook_id, 10, type: :string, json_name: "hookId")
  field(:request_token, 7, type: :string, json_name: "requestToken")
  field(:created_at, 8, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:finished_at, 9, type: Google.Protobuf.Timestamp, json_name: "finishedAt")
end

defmodule InternalApi.Task.ScheduleRequest.Job.Agent.Machine do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: :string)
  field(:os_image, 2, type: :string, json_name: "osImage")
end

defmodule InternalApi.Task.ScheduleRequest.Job.Agent.Container do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:image, 2, type: :string)
  field(:command, 3, type: :string)

  field(:env_vars, 4,
    repeated: true,
    type: InternalApi.Task.ScheduleRequest.Job.EnvVar,
    json_name: "envVars"
  )

  field(:secrets, 5, repeated: true, type: InternalApi.Task.ScheduleRequest.Job.Secret)
  field(:entrypoint, 6, type: :string)
  field(:user, 7, type: :string)
end

defmodule InternalApi.Task.ScheduleRequest.Job.Agent.ImagePullSecret do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
end

defmodule InternalApi.Task.ScheduleRequest.Job.Agent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:machine, 1, type: InternalApi.Task.ScheduleRequest.Job.Agent.Machine)

  field(:containers, 2, repeated: true, type: InternalApi.Task.ScheduleRequest.Job.Agent.Container)

  field(:image_pull_secrets, 3,
    repeated: true,
    type: InternalApi.Task.ScheduleRequest.Job.Agent.ImagePullSecret,
    json_name: "imagePullSecrets"
  )
end

defmodule InternalApi.Task.ScheduleRequest.Job.EnvVar do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.Task.ScheduleRequest.Job.Secret do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
end

defmodule InternalApi.Task.ScheduleRequest.Job do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:agent, 2, type: InternalApi.Task.ScheduleRequest.Job.Agent)

  field(:env_vars, 3,
    repeated: true,
    type: InternalApi.Task.ScheduleRequest.Job.EnvVar,
    json_name: "envVars"
  )

  field(:secrets, 4, repeated: true, type: InternalApi.Task.ScheduleRequest.Job.Secret)
  field(:prologue_commands, 5, repeated: true, type: :string, json_name: "prologueCommands")
  field(:commands, 6, repeated: true, type: :string)
  field(:epilogue_always_cmds, 8, repeated: true, type: :string, json_name: "epilogueAlwaysCmds")
  field(:epilogue_on_pass_cmds, 9, repeated: true, type: :string, json_name: "epilogueOnPassCmds")

  field(:epilogue_on_fail_cmds, 10, repeated: true, type: :string, json_name: "epilogueOnFailCmds")

  field(:execution_time_limit, 11, type: :int32, json_name: "executionTimeLimit")
  field(:priority, 12, type: :int32)
end

defmodule InternalApi.Task.ScheduleRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:jobs, 1, repeated: true, type: InternalApi.Task.ScheduleRequest.Job)
  field(:request_token, 2, type: :string, json_name: "requestToken")
  field(:ppl_id, 3, type: :string, json_name: "pplId")
  field(:wf_id, 4, type: :string, json_name: "wfId")
  field(:hook_id, 8, type: :string, json_name: "hookId")
  field(:project_id, 5, type: :string, json_name: "projectId")
  field(:repository_id, 9, type: :string, json_name: "repositoryId")
  field(:deployment_target_id, 10, type: :string, json_name: "deploymentTargetId")
  field(:org_id, 6, type: :string, json_name: "orgId")

  field(:fail_fast, 7,
    type: InternalApi.Task.ScheduleRequest.FailFast,
    json_name: "failFast",
    enum: true
  )
end

defmodule InternalApi.Task.ScheduleResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:task, 1, type: InternalApi.Task.Task)
end

defmodule InternalApi.Task.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:task_id, 1, type: :string, json_name: "taskId")
end

defmodule InternalApi.Task.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:task, 1, type: InternalApi.Task.Task)
end

defmodule InternalApi.Task.DescribeManyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:task_ids, 1, repeated: true, type: :string, json_name: "taskIds")
end

defmodule InternalApi.Task.DescribeManyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:tasks, 1, repeated: true, type: InternalApi.Task.Task)
end

defmodule InternalApi.Task.TerminateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:task_id, 1, type: :string, json_name: "taskId")
end

defmodule InternalApi.Task.TerminateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:message, 1, type: :string)
end

defmodule InternalApi.Task.TaskStarted do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:task_id, 1, type: :string, json_name: "taskId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Task.TaskFinished do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:task_id, 1, type: :string, json_name: "taskId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Task.TaskService.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Task.TaskService", protoc_gen_elixir_version: "0.13.0"

  rpc(:Schedule, InternalApi.Task.ScheduleRequest, InternalApi.Task.ScheduleResponse)

  rpc(:Describe, InternalApi.Task.DescribeRequest, InternalApi.Task.DescribeResponse)

  rpc(:DescribeMany, InternalApi.Task.DescribeManyRequest, InternalApi.Task.DescribeManyResponse)

  rpc(:Terminate, InternalApi.Task.TerminateRequest, InternalApi.Task.TerminateResponse)
end

defmodule InternalApi.Task.TaskService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Task.TaskService.Service
end
