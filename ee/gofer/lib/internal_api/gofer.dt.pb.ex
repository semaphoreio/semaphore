defmodule InternalApi.Gofer.DeploymentTargets.VerifyRequest.GitRefType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :BRANCH, 0
  field :TAG, 1
  field :PR, 2
end
defmodule InternalApi.Gofer.DeploymentTargets.VerifyResponse.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :SYNCING_TARGET, 0
  field :ACCESS_GRANTED, 1
  field :BANNED_SUBJECT, 2
  field :BANNED_OBJECT, 3
  field :CORDONED_TARGET, 4
  field :CORRUPTED_TARGET, 5
end
defmodule InternalApi.Gofer.DeploymentTargets.HistoryRequest.CursorType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :FIRST, 0
  field :AFTER, 1
  field :BEFORE, 2
end
defmodule InternalApi.Gofer.DeploymentTargets.DeploymentTarget.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :SYNCING, 0
  field :USABLE, 1
  field :UNUSABLE, 2
  field :CORDONED, 3
end
defmodule InternalApi.Gofer.DeploymentTargets.Deployment.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :PENDING, 0
  field :STARTED, 1
  field :FAILED, 2
end
defmodule InternalApi.Gofer.DeploymentTargets.SubjectRule.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :USER, 0
  field :ROLE, 1
  field :GROUP, 2
  field :AUTO, 3
  field :ANY, 4
end
defmodule InternalApi.Gofer.DeploymentTargets.ObjectRule.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :BRANCH, 0
  field :TAG, 1
  field :PR, 2
end
defmodule InternalApi.Gofer.DeploymentTargets.ObjectRule.Mode do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ALL, 0
  field :EXACT, 1
  field :REGEX, 2
end
defmodule InternalApi.Gofer.DeploymentTargets.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :requester_id, 2, type: :string, json_name: "requesterId"
end
defmodule InternalApi.Gofer.DeploymentTargets.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :targets, 1, repeated: true, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget
end
defmodule InternalApi.Gofer.DeploymentTargets.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :target_name, 2, type: :string, json_name: "targetName"
  field :target_id, 3, type: :string, json_name: "targetId"
end
defmodule InternalApi.Gofer.DeploymentTargets.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget
end
defmodule InternalApi.Gofer.DeploymentTargets.VerifyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target_id, 1, type: :string, json_name: "targetId"
  field :triggerer, 2, type: :string

  field :git_ref_type, 3,
    type: InternalApi.Gofer.DeploymentTargets.VerifyRequest.GitRefType,
    json_name: "gitRefType",
    enum: true

  field :git_ref_label, 4, type: :string, json_name: "gitRefLabel"
end
defmodule InternalApi.Gofer.DeploymentTargets.VerifyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :status, 1, type: InternalApi.Gofer.DeploymentTargets.VerifyResponse.Status, enum: true
end
defmodule InternalApi.Gofer.DeploymentTargets.HistoryRequest.Filters do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :git_ref_type, 1, type: :string, json_name: "gitRefType"
  field :git_ref_label, 2, type: :string, json_name: "gitRefLabel"
  field :triggered_by, 3, type: :string, json_name: "triggeredBy"
  field :parameter1, 4, type: :string
  field :parameter2, 5, type: :string
  field :parameter3, 6, type: :string
end
defmodule InternalApi.Gofer.DeploymentTargets.HistoryRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target_id, 1, type: :string, json_name: "targetId"

  field :cursor_type, 2,
    type: InternalApi.Gofer.DeploymentTargets.HistoryRequest.CursorType,
    json_name: "cursorType",
    enum: true

  field :cursor_value, 3, type: :uint64, json_name: "cursorValue"
  field :filters, 4, type: InternalApi.Gofer.DeploymentTargets.HistoryRequest.Filters
  field :requester_id, 5, type: :string, json_name: "requesterId"
end
defmodule InternalApi.Gofer.DeploymentTargets.HistoryResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :deployments, 1, repeated: true, type: InternalApi.Gofer.DeploymentTargets.Deployment
  field :cursor_before, 2, type: :uint64, json_name: "cursorBefore"
  field :cursor_after, 3, type: :uint64, json_name: "cursorAfter"
end
defmodule InternalApi.Gofer.DeploymentTargets.CordonRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target_id, 1, type: :string, json_name: "targetId"
  field :cordoned, 2, type: :bool
end
defmodule InternalApi.Gofer.DeploymentTargets.CordonResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target_id, 1, type: :string, json_name: "targetId"
  field :cordoned, 2, type: :bool
end
defmodule InternalApi.Gofer.DeploymentTargets.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget
  field :secret, 2, type: InternalApi.Gofer.DeploymentTargets.EncryptedSecretData
  field :unique_token, 3, type: :string, json_name: "uniqueToken"
  field :requester_id, 4, type: :string, json_name: "requesterId"
end
defmodule InternalApi.Gofer.DeploymentTargets.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget
end
defmodule InternalApi.Gofer.DeploymentTargets.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget
  field :secret, 2, type: InternalApi.Gofer.DeploymentTargets.EncryptedSecretData
  field :unique_token, 3, type: :string, json_name: "uniqueToken"
  field :requester_id, 4, type: :string, json_name: "requesterId"
end
defmodule InternalApi.Gofer.DeploymentTargets.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget
end
defmodule InternalApi.Gofer.DeploymentTargets.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target_id, 1, type: :string, json_name: "targetId"
  field :requester_id, 2, type: :string, json_name: "requesterId"
  field :unique_token, 3, type: :string, json_name: "uniqueToken"
end
defmodule InternalApi.Gofer.DeploymentTargets.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :target_id, 1, type: :string, json_name: "targetId"
end
defmodule InternalApi.Gofer.DeploymentTargets.DeploymentTarget do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :description, 3, type: :string
  field :url, 4, type: :string
  field :organization_id, 5, type: :string, json_name: "organizationId"
  field :project_id, 6, type: :string, json_name: "projectId"
  field :created_by, 7, type: :string, json_name: "createdBy"
  field :updated_by, 8, type: :string, json_name: "updatedBy"
  field :created_at, 9, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 10, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
  field :state, 11, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget.State, enum: true
  field :state_message, 12, type: :string, json_name: "stateMessage"

  field :subject_rules, 13,
    repeated: true,
    type: InternalApi.Gofer.DeploymentTargets.SubjectRule,
    json_name: "subjectRules"

  field :object_rules, 14,
    repeated: true,
    type: InternalApi.Gofer.DeploymentTargets.ObjectRule,
    json_name: "objectRules"

  field :last_deployment, 15,
    type: InternalApi.Gofer.DeploymentTargets.Deployment,
    json_name: "lastDeployment"

  field :cordoned, 16, type: :bool
  field :bookmark_parameter1, 17, type: :string, json_name: "bookmarkParameter1"
  field :bookmark_parameter2, 18, type: :string, json_name: "bookmarkParameter2"
  field :bookmark_parameter3, 19, type: :string, json_name: "bookmarkParameter3"
  field :secret_name, 20, type: :string, json_name: "secretName"
end
defmodule InternalApi.Gofer.DeploymentTargets.Deployment.EnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :value, 2, type: :string
end
defmodule InternalApi.Gofer.DeploymentTargets.Deployment do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :id, 1, type: :string
  field :target_id, 2, type: :string, json_name: "targetId"
  field :prev_pipeline_id, 3, type: :string, json_name: "prevPipelineId"
  field :pipeline_id, 4, type: :string, json_name: "pipelineId"
  field :triggered_by, 5, type: :string, json_name: "triggeredBy"
  field :triggered_at, 6, type: Google.Protobuf.Timestamp, json_name: "triggeredAt"
  field :state, 7, type: InternalApi.Gofer.DeploymentTargets.Deployment.State, enum: true
  field :state_message, 8, type: :string, json_name: "stateMessage"
  field :switch_id, 9, type: :string, json_name: "switchId"
  field :target_name, 10, type: :string, json_name: "targetName"

  field :env_vars, 11,
    repeated: true,
    type: InternalApi.Gofer.DeploymentTargets.Deployment.EnvVar,
    json_name: "envVars"

  field :can_requester_rerun, 12, type: :bool, json_name: "canRequesterRerun"
end
defmodule InternalApi.Gofer.DeploymentTargets.SubjectRule do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :type, 1, type: InternalApi.Gofer.DeploymentTargets.SubjectRule.Type, enum: true
  field :subject_id, 2, type: :string, json_name: "subjectId"
end
defmodule InternalApi.Gofer.DeploymentTargets.ObjectRule do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :type, 1, type: InternalApi.Gofer.DeploymentTargets.ObjectRule.Type, enum: true

  field :match_mode, 2,
    type: InternalApi.Gofer.DeploymentTargets.ObjectRule.Mode,
    json_name: "matchMode",
    enum: true

  field :pattern, 3, type: :string
end
defmodule InternalApi.Gofer.DeploymentTargets.EncryptedSecretData do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :key_id, 2, type: :string, json_name: "keyId"
  field :aes256_key, 3, type: :string, json_name: "aes256Key"
  field :init_vector, 4, type: :string, json_name: "initVector"
  field :payload, 5, type: :string
end
defmodule InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Service do
  @moduledoc false
  use GRPC.Service,
    name: "InternalApi.Gofer.DeploymentTargets.DeploymentTargets",
    protoc_gen_elixir_version: "0.10.0"

  rpc :List,
      InternalApi.Gofer.DeploymentTargets.ListRequest,
      InternalApi.Gofer.DeploymentTargets.ListResponse

  rpc :Describe,
      InternalApi.Gofer.DeploymentTargets.DescribeRequest,
      InternalApi.Gofer.DeploymentTargets.DescribeResponse

  rpc :Verify,
      InternalApi.Gofer.DeploymentTargets.VerifyRequest,
      InternalApi.Gofer.DeploymentTargets.VerifyResponse

  rpc :History,
      InternalApi.Gofer.DeploymentTargets.HistoryRequest,
      InternalApi.Gofer.DeploymentTargets.HistoryResponse

  rpc :Cordon,
      InternalApi.Gofer.DeploymentTargets.CordonRequest,
      InternalApi.Gofer.DeploymentTargets.CordonResponse

  rpc :Create,
      InternalApi.Gofer.DeploymentTargets.CreateRequest,
      InternalApi.Gofer.DeploymentTargets.CreateResponse

  rpc :Update,
      InternalApi.Gofer.DeploymentTargets.UpdateRequest,
      InternalApi.Gofer.DeploymentTargets.UpdateResponse

  rpc :Delete,
      InternalApi.Gofer.DeploymentTargets.DeleteRequest,
      InternalApi.Gofer.DeploymentTargets.DeleteResponse
end

defmodule InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Service
end
