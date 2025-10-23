defmodule InternalApi.EphemeralEnvironments.StageType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:STAGE_TYPE_UNSPECIFIED, 0)
  field(:STAGE_TYPE_PROVISION, 1)
  field(:STAGE_TYPE_DEPLOY, 2)
  field(:STAGE_TYPE_DEPROVISION, 3)
end

defmodule InternalApi.EphemeralEnvironments.InstanceState do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:INSTANCE_STATE_UNSPECIFIED, 0)
  field(:INSTANCE_STATE_ZERO_STATE, 1)
  field(:INSTANCE_STATE_PROVISIONING, 2)
  field(:INSTANCE_STATE_READY_TO_USE, 3)
  field(:INSTANCE_STATE_SLEEP, 4)
  field(:INSTANCE_STATE_IN_USE, 5)
  field(:INSTANCE_STATE_DEPLOYING, 6)
  field(:INSTANCE_STATE_DEPROVISIONING, 7)
  field(:INSTANCE_STATE_DESTROYED, 8)
  field(:INSTANCE_STATE_ACKNOWLEDGED_CLEANUP, 9)
  field(:INSTANCE_STATE_FAILED_PROVISIONING, 10)
  field(:INSTANCE_STATE_FAILED_DEPROVISIONING, 11)
  field(:INSTANCE_STATE_FAILED_DEPLOYMENT, 12)
  field(:INSTANCE_STATE_FAILED_CLEANUP, 13)
  field(:INSTANCE_STATE_FAILED_SLEEP, 14)
  field(:INSTANCE_STATE_FAILED_WAKE_UP, 15)
end

defmodule InternalApi.EphemeralEnvironments.StateChangeActionType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:STATE_CHANGE_ACTION_TYPE_UNSPECIFIED, 0)
  field(:STATE_CHANGE_ACTION_TYPE_PROVISIONING, 1)
  field(:STATE_CHANGE_ACTION_TYPE_CLEANUP, 2)
  field(:STATE_CHANGE_ACTION_TYPE_TO_SLEEP, 3)
  field(:STATE_CHANGE_ACTION_TYPE_WAKE_UP, 4)
  field(:STATE_CHANGE_ACTION_TYPE_DEPLOYING, 5)
  field(:STATE_CHANGE_ACTION_TYPE_CLEANING_UP, 6)
  field(:STATE_CHANGE_ACTION_TYPE_DEPROVISIONING, 7)
end

defmodule InternalApi.EphemeralEnvironments.StateChangeResult do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:STATE_CHANGE_RESULT_UNSPECIFIED, 0)
  field(:STATE_CHANGE_RESULT_PASSED, 1)
  field(:STATE_CHANGE_RESULT_PENDING, 2)
  field(:STATE_CHANGE_RESULT_FAILED, 3)
end

defmodule InternalApi.EphemeralEnvironments.TriggererType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:TRIGGERER_TYPE_UNSPECIFIED, 0)
  field(:TRIGGERER_TYPE_USER, 1)
  field(:TRIGGERER_TYPE_AUTOMATION_RULE, 2)
end

defmodule InternalApi.EphemeralEnvironments.TypeState do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:TYPE_STATE_UNSPECIFIED, 0)
  field(:TYPE_STATE_DRAFT, 1)
  field(:TYPE_STATE_READY, 2)
  field(:TYPE_STATE_CORDONED, 3)
  field(:TYPE_STATE_DELETED, 4)
end

defmodule InternalApi.EphemeralEnvironments.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
end

defmodule InternalApi.EphemeralEnvironments.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:environment_types, 1,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType,
    json_name: "environmentTypes"
  )
end

defmodule InternalApi.EphemeralEnvironments.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string, json_name: "orgId")
end

defmodule InternalApi.EphemeralEnvironments.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:environment_type, 1,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType,
    json_name: "environmentType"
  )

  field(:instances, 2,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentInstance
  )
end

defmodule InternalApi.EphemeralEnvironments.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:environment_type, 1,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType,
    json_name: "environmentType"
  )
end

defmodule InternalApi.EphemeralEnvironments.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:environment_type, 1,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType,
    json_name: "environmentType"
  )
end

defmodule InternalApi.EphemeralEnvironments.DeleteRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string, json_name: "orgId")
end

defmodule InternalApi.EphemeralEnvironments.DeleteResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.EphemeralEnvironments.CordonRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string, json_name: "orgId")
end

defmodule InternalApi.EphemeralEnvironments.CordonResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:environment_type, 1,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType,
    json_name: "environmentType"
  )
end

defmodule InternalApi.EphemeralEnvironments.UpdateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:environment_type, 1,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType,
    json_name: "environmentType"
  )
end

defmodule InternalApi.EphemeralEnvironments.UpdateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:environment_type, 1,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType,
    json_name: "environmentType"
  )
end

defmodule InternalApi.EphemeralEnvironments.EphemeralEnvironmentType do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:name, 3, type: :string)
  field(:description, 4, type: :string)
  field(:created_by, 5, type: :string, json_name: "createdBy")
  field(:last_updated_by, 6, type: :string, json_name: "lastUpdatedBy")
  field(:created_at, 7, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 8, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
  field(:state, 9, type: InternalApi.EphemeralEnvironments.TypeState, enum: true)
  field(:max_number_of_instances, 10, type: :int32, json_name: "maxNumberOfInstances")
  field(:stages, 11, repeated: true, type: InternalApi.EphemeralEnvironments.StageConfig)

  field(:environment_context, 12,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.EnvironmentContext,
    json_name: "environmentContext"
  )

  field(:accessible_project_ids, 13,
    repeated: true,
    type: :string,
    json_name: "accessibleProjectIds"
  )

  field(:ttl_config, 14,
    type: InternalApi.EphemeralEnvironments.TTLConfig,
    json_name: "ttlConfig"
  )
end

defmodule InternalApi.EphemeralEnvironments.StageConfig do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: InternalApi.EphemeralEnvironments.StageType, enum: true)
  field(:pipeline, 2, type: InternalApi.EphemeralEnvironments.PipelineConfig)
  field(:parameters, 3, repeated: true, type: InternalApi.EphemeralEnvironments.StageParameter)

  field(:rbac_rules, 4,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.RBACRule,
    json_name: "rbacRules"
  )
end

defmodule InternalApi.EphemeralEnvironments.StageParameter do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:description, 2, type: :string)
  field(:required, 3, type: :bool)
end

defmodule InternalApi.EphemeralEnvironments.RBACRule do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:subject_type, 1,
    type: InternalApi.RBAC.SubjectType,
    json_name: "subjectType",
    enum: true
  )

  field(:subject_id, 2, type: :string, json_name: "subjectId")
end

defmodule InternalApi.EphemeralEnvironments.EnvironmentContext do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:description, 2, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.PipelineConfig do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:branch, 2, type: :string)
  field(:pipeline_yaml_file, 3, type: :string, json_name: "pipelineYamlFile")
end

defmodule InternalApi.EphemeralEnvironments.TTLConfig do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:duration_hours, 1, type: :int32, json_name: "durationHours")
  field(:allow_extension, 2, type: :bool, json_name: "allowExtension")
end

defmodule InternalApi.EphemeralEnvironments.EphemeralEnvironmentInstance do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:ee_type_id, 2, type: :string, json_name: "eeTypeId")
  field(:name, 3, type: :string)
  field(:state, 4, type: InternalApi.EphemeralEnvironments.InstanceState, enum: true)
  field(:last_state_change_id, 5, type: :string, json_name: "lastStateChangeId")
  field(:created_at, 6, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 7, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
end

defmodule InternalApi.EphemeralEnvironments.EphemeralSecretDefinition do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:ee_type_id, 2, type: :string, json_name: "eeTypeId")
  field(:name, 3, type: :string)
  field(:description, 4, type: :string)

  field(:actions_that_can_change_the_secret, 5,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.StateChangeAction,
    json_name: "actionsThatCanChangeTheSecret"
  )

  field(:actions_that_have_access_to_the_secret, 6,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.StateChangeAction,
    json_name: "actionsThatHaveAccessToTheSecret"
  )
end

defmodule InternalApi.EphemeralEnvironments.StateChangeAction do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:type, 2, type: InternalApi.EphemeralEnvironments.StateChangeActionType, enum: true)
  field(:project_id, 3, type: :string, json_name: "projectId")
  field(:branch, 4, type: :string)
  field(:pipeline_yaml_name, 5, type: :string, json_name: "pipelineYamlName")
  field(:execution_auth_rules, 6, type: :string, json_name: "executionAuthRules")
end

defmodule InternalApi.EphemeralEnvironments.InstanceStateChange do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:instance_id, 2, type: :string, json_name: "instanceId")

  field(:prev_state, 3,
    type: InternalApi.EphemeralEnvironments.InstanceState,
    json_name: "prevState",
    enum: true
  )

  field(:next_state, 4,
    type: InternalApi.EphemeralEnvironments.InstanceState,
    json_name: "nextState",
    enum: true
  )

  field(:state_change_action, 5,
    type: InternalApi.EphemeralEnvironments.StateChangeAction,
    json_name: "stateChangeAction"
  )

  field(:result, 6, type: InternalApi.EphemeralEnvironments.StateChangeResult, enum: true)
  field(:TriggererType, 7, type: :string)
  field(:trigger_id, 8, type: :string, json_name: "triggerId")
  field(:execution_pipeline_id, 9, type: :string, json_name: "executionPipelineId")
  field(:execution_workflow_id, 10, type: :string, json_name: "executionWorkflowId")
  field(:started_at, 11, type: Google.Protobuf.Timestamp, json_name: "startedAt")
  field(:finished_at, 12, type: Google.Protobuf.Timestamp, json_name: "finishedAt")
end

defmodule InternalApi.EphemeralEnvironments.EphemeralEnvironments.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.EphemeralEnvironments.EphemeralEnvironments",
    protoc_gen_elixir_version: "0.13.0"

  rpc(
    :List,
    InternalApi.EphemeralEnvironments.ListRequest,
    InternalApi.EphemeralEnvironments.ListResponse
  )

  rpc(
    :Describe,
    InternalApi.EphemeralEnvironments.DescribeRequest,
    InternalApi.EphemeralEnvironments.DescribeResponse
  )

  rpc(
    :Create,
    InternalApi.EphemeralEnvironments.CreateRequest,
    InternalApi.EphemeralEnvironments.CreateResponse
  )

  rpc(
    :Update,
    InternalApi.EphemeralEnvironments.UpdateRequest,
    InternalApi.EphemeralEnvironments.UpdateResponse
  )

  rpc(
    :Delete,
    InternalApi.EphemeralEnvironments.DeleteRequest,
    InternalApi.EphemeralEnvironments.DeleteResponse
  )

  rpc(
    :Cordon,
    InternalApi.EphemeralEnvironments.CordonRequest,
    InternalApi.EphemeralEnvironments.CordonResponse
  )
end

defmodule InternalApi.EphemeralEnvironments.EphemeralEnvironments.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.EphemeralEnvironments.EphemeralEnvironments.Service
end
