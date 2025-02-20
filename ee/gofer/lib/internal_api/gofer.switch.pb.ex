defmodule InternalApi.Gofer.GitRefType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :BRANCH, 0
  field :TAG, 1
  field :PR, 2
end

defmodule InternalApi.Gofer.DeploymentTargetDescription.Access.Reason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :INTERNAL_ERROR, 0
  field :NO_REASON, 1
  field :SYNCING_TARGET, 2
  field :CORRUPTED_TARGET, 3
  field :BANNED_SUBJECT, 4
  field :BANNED_OBJECT, 5
  field :CORDONED_TARGET, 6
end

defmodule InternalApi.Gofer.TriggerEvent.ProcessingResult do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :PASSED, 0
  field :FAILED, 1
end

defmodule InternalApi.Gofer.ResponseStatus.ResponseCode do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :OK, 0
  field :BAD_PARAM, 1
  field :NOT_FOUND, 2
  field :RESULT_CHANGED, 3
  field :FAILED, 4
  field :REFUSED, 5
  field :RESULT_REASON_CHANGED, 6
  field :MALFORMED, 7
end

defmodule InternalApi.Gofer.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :pipeline_id, 1, type: :string, json_name: "pipelineId"
  field :targets, 2, repeated: true, type: InternalApi.Gofer.Target
  field :branch_name, 4, type: :string, json_name: "branchName"
  field :prev_ppl_artefact_ids, 5, repeated: true, type: :string, json_name: "prevPplArtefactIds"
  field :label, 6, type: :string
  field :git_ref_type, 7, type: InternalApi.Gofer.GitRefType, json_name: "gitRefType", enum: true
  field :project_id, 8, type: :string, json_name: "projectId"
  field :commit_sha, 9, type: :string, json_name: "commitSha"
  field :working_dir, 10, type: :string, json_name: "workingDir"
  field :commit_range, 11, type: :string, json_name: "commitRange"
  field :yml_file_name, 12, type: :string, json_name: "ymlFileName"
  field :pr_base, 13, type: :string, json_name: "prBase"
  field :pr_sha, 14, type: :string, json_name: "prSha"
end

defmodule InternalApi.Gofer.Target do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :pipeline_path, 2, type: :string, json_name: "pipelinePath"

  field :auto_trigger_on, 5,
    repeated: true,
    type: InternalApi.Gofer.AutoTriggerCond,
    json_name: "autoTriggerOn"

  field :parameter_env_vars, 6,
    repeated: true,
    type: InternalApi.Gofer.ParamEnvVar,
    json_name: "parameterEnvVars"

  field :auto_promote_when, 7, type: :string, json_name: "autoPromoteWhen"
  field :deployment_target, 8, type: :string, json_name: "deploymentTarget"
end

defmodule InternalApi.Gofer.ParamEnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :options, 2, repeated: true, type: :string
  field :required, 3, type: :bool
  field :default_value, 4, type: :string, json_name: "defaultValue"
  field :description, 5, type: :string
end

defmodule InternalApi.Gofer.AutoTriggerCond do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :result, 1, type: :string
  field :branch, 2, repeated: true, type: :string
  field :result_reason, 3, type: :string, json_name: "resultReason"
  field :labels, 4, repeated: true, type: :string
  field :label_patterns, 5, repeated: true, type: :string, json_name: "labelPatterns"
end

defmodule InternalApi.Gofer.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Gofer.ResponseStatus, json_name: "responseStatus"
  field :switch_id, 2, type: :string, json_name: "switchId"
end

defmodule InternalApi.Gofer.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :switch_id, 1, type: :string, json_name: "switchId"
  field :events_per_target, 2, type: :int32, json_name: "eventsPerTarget"
  field :requester_id, 3, type: :string, json_name: "requesterId"
end

defmodule InternalApi.Gofer.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Gofer.ResponseStatus, json_name: "responseStatus"
  field :switch_id, 2, type: :string, json_name: "switchId"
  field :ppl_id, 3, type: :string, json_name: "pplId"
  field :pipeline_done, 4, type: :bool, json_name: "pipelineDone"
  field :pipeline_result, 5, type: :string, json_name: "pipelineResult"
  field :targets, 6, repeated: true, type: InternalApi.Gofer.TargetDescription
  field :pipeline_result_reason, 7, type: :string, json_name: "pipelineResultReason"
end

defmodule InternalApi.Gofer.TargetDescription do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :pipeline_path, 2, type: :string, json_name: "pipelinePath"

  field :trigger_events, 4,
    repeated: true,
    type: InternalApi.Gofer.TriggerEvent,
    json_name: "triggerEvents"

  field :auto_trigger_on, 6,
    repeated: true,
    type: InternalApi.Gofer.AutoTriggerCond,
    json_name: "autoTriggerOn"

  field :parameter_env_vars, 7,
    repeated: true,
    type: InternalApi.Gofer.ParamEnvVar,
    json_name: "parameterEnvVars"

  field :dt_description, 8,
    type: InternalApi.Gofer.DeploymentTargetDescription,
    json_name: "dtDescription"
end

defmodule InternalApi.Gofer.DeploymentTargetDescription.Access do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :allowed, 1, type: :bool
  field :reason, 2, type: InternalApi.Gofer.DeploymentTargetDescription.Access.Reason, enum: true
  field :message, 3, type: :string
end

defmodule InternalApi.Gofer.DeploymentTargetDescription do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target_id, 1, type: :string, json_name: "targetId"
  field :target_name, 2, type: :string, json_name: "targetName"
  field :access, 3, type: InternalApi.Gofer.DeploymentTargetDescription.Access
end

defmodule InternalApi.Gofer.TriggerEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target_name, 1, type: :string, json_name: "targetName"
  field :triggered_at, 2, type: Google.Protobuf.Timestamp, json_name: "triggeredAt"
  field :auto_triggered, 3, type: :bool, json_name: "autoTriggered"
  field :triggered_by, 4, type: :string, json_name: "triggeredBy"
  field :override, 5, type: :bool
  field :processed, 6, type: :bool

  field :processing_result, 7,
    type: InternalApi.Gofer.TriggerEvent.ProcessingResult,
    json_name: "processingResult",
    enum: true

  field :scheduled_at, 8, type: Google.Protobuf.Timestamp, json_name: "scheduledAt"
  field :scheduled_pipeline_id, 9, type: :string, json_name: "scheduledPipelineId"
  field :error_response, 10, type: :string, json_name: "errorResponse"

  field :env_variables, 11,
    repeated: true,
    type: InternalApi.Gofer.EnvVariable,
    json_name: "envVariables"
end

defmodule InternalApi.Gofer.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :switch_ids, 1, repeated: true, type: :string, json_name: "switchIds"
  field :events_per_target, 2, type: :int32, json_name: "eventsPerTarget"
  field :requester_id, 3, type: :string, json_name: "requesterId"
end

defmodule InternalApi.Gofer.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Gofer.ResponseStatus, json_name: "responseStatus"
  field :switches, 2, repeated: true, type: InternalApi.Gofer.SwitchDetails
end

defmodule InternalApi.Gofer.SwitchDetails do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :switch_id, 1, type: :string, json_name: "switchId"
  field :ppl_id, 2, type: :string, json_name: "pplId"
  field :pipeline_done, 3, type: :bool, json_name: "pipelineDone"
  field :pipeline_result, 4, type: :string, json_name: "pipelineResult"
  field :pipeline_result_reason, 5, type: :string, json_name: "pipelineResultReason"
  field :targets, 6, repeated: true, type: InternalApi.Gofer.TargetDescription
end

defmodule InternalApi.Gofer.ListTriggerEventsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :switch_id, 1, type: :string, json_name: "switchId"
  field :target_name, 2, type: :string, json_name: "targetName"
  field :page, 3, type: :int32
  field :page_size, 4, type: :int32, json_name: "pageSize"
end

defmodule InternalApi.Gofer.ListTriggerEventsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Gofer.ResponseStatus, json_name: "responseStatus"

  field :trigger_events, 2,
    repeated: true,
    type: InternalApi.Gofer.TriggerEvent,
    json_name: "triggerEvents"

  field :page_number, 3, type: :int32, json_name: "pageNumber"
  field :page_size, 4, type: :int32, json_name: "pageSize"
  field :total_entries, 5, type: :int32, json_name: "totalEntries"
  field :total_pages, 6, type: :int32, json_name: "totalPages"
end

defmodule InternalApi.Gofer.PipelineDoneRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :switch_id, 1, type: :string, json_name: "switchId"
  field :result, 2, type: :string
  field :result_reason, 3, type: :string, json_name: "resultReason"
end

defmodule InternalApi.Gofer.PipelineDoneResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Gofer.ResponseStatus, json_name: "responseStatus"
end

defmodule InternalApi.Gofer.TriggerRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :switch_id, 1, type: :string, json_name: "switchId"
  field :target_name, 2, type: :string, json_name: "targetName"
  field :triggered_by, 3, type: :string, json_name: "triggeredBy"
  field :override, 4, type: :bool
  field :request_token, 5, type: :string, json_name: "requestToken"

  field :env_variables, 6,
    repeated: true,
    type: InternalApi.Gofer.EnvVariable,
    json_name: "envVariables"
end

defmodule InternalApi.Gofer.EnvVariable do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :value, 2, type: :string
end

defmodule InternalApi.Gofer.TriggerResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Gofer.ResponseStatus, json_name: "responseStatus"
end

defmodule InternalApi.Gofer.VersionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"
end

defmodule InternalApi.Gofer.VersionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :version, 1, type: :string
end

defmodule InternalApi.Gofer.ResponseStatus do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :code, 1, type: InternalApi.Gofer.ResponseStatus.ResponseCode, enum: true
  field :message, 2, type: :string
end

defmodule InternalApi.Gofer.Switch.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Gofer.Switch", protoc_gen_elixir_version: "0.10.0"

  rpc :Create, InternalApi.Gofer.CreateRequest, InternalApi.Gofer.CreateResponse

  rpc :Describe, InternalApi.Gofer.DescribeRequest, InternalApi.Gofer.DescribeResponse

  rpc :DescribeMany, InternalApi.Gofer.DescribeManyRequest, InternalApi.Gofer.DescribeManyResponse

  rpc :ListTriggerEvents,
      InternalApi.Gofer.ListTriggerEventsRequest,
      InternalApi.Gofer.ListTriggerEventsResponse

  rpc :PipelineDone, InternalApi.Gofer.PipelineDoneRequest, InternalApi.Gofer.PipelineDoneResponse

  rpc :Trigger, InternalApi.Gofer.TriggerRequest, InternalApi.Gofer.TriggerResponse

  rpc :Version, InternalApi.Gofer.VersionRequest, InternalApi.Gofer.VersionResponse
end

defmodule InternalApi.Gofer.Switch.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Gofer.Switch.Service
end
