defmodule InternalApi.EphemeralEnvironments.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t()
        }
  defstruct [:org_id, :project_id]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          environment_types: [InternalApi.EphemeralEnvironments.EphemeralEnvironmentType.t()]
        }
  defstruct [:environment_types]

  field(:environment_types, 1,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType
  )
end

defmodule InternalApi.EphemeralEnvironments.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          org_id: String.t()
        }
  defstruct [:id, :org_id]

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          environment_type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType.t(),
          instances: [InternalApi.EphemeralEnvironments.EphemeralEnvironmentInstance.t()]
        }
  defstruct [:environment_type, :instances]

  field(:environment_type, 1, type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType)

  field(:instances, 2,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentInstance
  )
end

defmodule InternalApi.EphemeralEnvironments.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          environment_type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType.t()
        }
  defstruct [:environment_type]

  field(:environment_type, 1, type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType)
end

defmodule InternalApi.EphemeralEnvironments.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          environment_type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType.t()
        }
  defstruct [:environment_type]

  field(:environment_type, 1, type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType)
end

defmodule InternalApi.EphemeralEnvironments.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          org_id: String.t()
        }
  defstruct [:id, :org_id]

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.EphemeralEnvironments.CordonRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          org_id: String.t()
        }
  defstruct [:id, :org_id]

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.CordonResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          environment_type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType.t()
        }
  defstruct [:environment_type]

  field(:environment_type, 1, type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType)
end

defmodule InternalApi.EphemeralEnvironments.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          environment_type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType.t()
        }
  defstruct [:environment_type]

  field(:environment_type, 1, type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType)
end

defmodule InternalApi.EphemeralEnvironments.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          environment_type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType.t()
        }
  defstruct [:environment_type]

  field(:environment_type, 1, type: InternalApi.EphemeralEnvironments.EphemeralEnvironmentType)
end

defmodule InternalApi.EphemeralEnvironments.EphemeralEnvironmentType do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          org_id: String.t(),
          name: String.t(),
          description: String.t(),
          created_by: String.t(),
          last_updated_by: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t(),
          state: integer,
          max_number_of_instances: integer,
          stages: [InternalApi.EphemeralEnvironments.StageConfig.t()],
          environment_context: [InternalApi.EphemeralEnvironments.EnvironmentContext.t()],
          accessible_project_ids: [String.t()],
          ttl_config: InternalApi.EphemeralEnvironments.TTLConfig.t()
        }
  defstruct [
    :id,
    :org_id,
    :name,
    :description,
    :created_by,
    :last_updated_by,
    :created_at,
    :updated_at,
    :state,
    :max_number_of_instances,
    :stages,
    :environment_context,
    :accessible_project_ids,
    :ttl_config
  ]

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:description, 4, type: :string)
  field(:created_by, 5, type: :string)
  field(:last_updated_by, 6, type: :string)
  field(:created_at, 7, type: Google.Protobuf.Timestamp)
  field(:updated_at, 8, type: Google.Protobuf.Timestamp)
  field(:state, 9, type: InternalApi.EphemeralEnvironments.TypeState, enum: true)
  field(:max_number_of_instances, 10, type: :int32)
  field(:stages, 11, repeated: true, type: InternalApi.EphemeralEnvironments.StageConfig)

  field(:environment_context, 12,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.EnvironmentContext
  )

  field(:accessible_project_ids, 13, repeated: true, type: :string)
  field(:ttl_config, 14, type: InternalApi.EphemeralEnvironments.TTLConfig)
end

defmodule InternalApi.EphemeralEnvironments.StageConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          pipeline: InternalApi.EphemeralEnvironments.PipelineConfig.t(),
          parameters: [InternalApi.EphemeralEnvironments.StageParameter.t()],
          rbac_rules: [InternalApi.EphemeralEnvironments.RBACRule.t()]
        }
  defstruct [:type, :pipeline, :parameters, :rbac_rules]

  field(:type, 1, type: InternalApi.EphemeralEnvironments.StageType, enum: true)
  field(:pipeline, 2, type: InternalApi.EphemeralEnvironments.PipelineConfig)
  field(:parameters, 3, repeated: true, type: InternalApi.EphemeralEnvironments.StageParameter)
  field(:rbac_rules, 4, repeated: true, type: InternalApi.EphemeralEnvironments.RBACRule)
end

defmodule InternalApi.EphemeralEnvironments.StageParameter do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          required: boolean
        }
  defstruct [:name, :description, :required]

  field(:name, 1, type: :string)
  field(:description, 2, type: :string)
  field(:required, 3, type: :bool)
end

defmodule InternalApi.EphemeralEnvironments.RBACRule do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          subject_type: integer,
          subject_id: String.t()
        }
  defstruct [:subject_type, :subject_id]

  field(:subject_type, 1, type: InternalApi.RBAC.SubjectType, enum: true)
  field(:subject_id, 2, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.EnvironmentContext do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t()
        }
  defstruct [:name, :description]

  field(:name, 1, type: :string)
  field(:description, 2, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.PipelineConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          branch: String.t(),
          pipeline_yaml_file: String.t()
        }
  defstruct [:project_id, :branch, :pipeline_yaml_file]

  field(:project_id, 1, type: :string)
  field(:branch, 2, type: :string)
  field(:pipeline_yaml_file, 3, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.TTLConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          duration_hours: integer,
          allow_extension: boolean
        }
  defstruct [:duration_hours, :allow_extension]

  field(:duration_hours, 1, type: :int32)
  field(:allow_extension, 2, type: :bool)
end

defmodule InternalApi.EphemeralEnvironments.EphemeralEnvironmentInstance do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          ee_type_id: String.t(),
          name: String.t(),
          state: integer,
          last_state_change_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:id, :ee_type_id, :name, :state, :last_state_change_id, :created_at, :updated_at]

  field(:id, 1, type: :string)
  field(:ee_type_id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:state, 4, type: InternalApi.EphemeralEnvironments.InstanceState, enum: true)
  field(:last_state_change_id, 5, type: :string)
  field(:created_at, 6, type: Google.Protobuf.Timestamp)
  field(:updated_at, 7, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.EphemeralEnvironments.EphemeralSecretDefinition do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          ee_type_id: String.t(),
          name: String.t(),
          description: String.t(),
          actions_that_can_change_the_secret: [
            InternalApi.EphemeralEnvironments.StateChangeAction.t()
          ],
          actions_that_have_access_to_the_secret: [
            InternalApi.EphemeralEnvironments.StateChangeAction.t()
          ]
        }
  defstruct [
    :id,
    :ee_type_id,
    :name,
    :description,
    :actions_that_can_change_the_secret,
    :actions_that_have_access_to_the_secret
  ]

  field(:id, 1, type: :string)
  field(:ee_type_id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:description, 4, type: :string)

  field(:actions_that_can_change_the_secret, 5,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.StateChangeAction
  )

  field(:actions_that_have_access_to_the_secret, 6,
    repeated: true,
    type: InternalApi.EphemeralEnvironments.StateChangeAction
  )
end

defmodule InternalApi.EphemeralEnvironments.StateChangeAction do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          type: integer,
          project_id: String.t(),
          branch: String.t(),
          pipeline_yaml_name: String.t(),
          execution_auth_rules: String.t()
        }
  defstruct [:id, :type, :project_id, :branch, :pipeline_yaml_name, :execution_auth_rules]

  field(:id, 1, type: :string)
  field(:type, 2, type: InternalApi.EphemeralEnvironments.StateChangeActionType, enum: true)
  field(:project_id, 3, type: :string)
  field(:branch, 4, type: :string)
  field(:pipeline_yaml_name, 5, type: :string)
  field(:execution_auth_rules, 6, type: :string)
end

defmodule InternalApi.EphemeralEnvironments.InstanceStateChange do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          instance_id: String.t(),
          prev_state: integer,
          next_state: integer,
          state_change_action: InternalApi.EphemeralEnvironments.StateChangeAction.t(),
          result: integer,
          TriggererType: String.t(),
          trigger_id: String.t(),
          execution_pipeline_id: String.t(),
          execution_workflow_id: String.t(),
          started_at: Google.Protobuf.Timestamp.t(),
          finished_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :id,
    :instance_id,
    :prev_state,
    :next_state,
    :state_change_action,
    :result,
    :TriggererType,
    :trigger_id,
    :execution_pipeline_id,
    :execution_workflow_id,
    :started_at,
    :finished_at
  ]

  field(:id, 1, type: :string)
  field(:instance_id, 2, type: :string)
  field(:prev_state, 3, type: InternalApi.EphemeralEnvironments.InstanceState, enum: true)
  field(:next_state, 4, type: InternalApi.EphemeralEnvironments.InstanceState, enum: true)
  field(:state_change_action, 5, type: InternalApi.EphemeralEnvironments.StateChangeAction)
  field(:result, 6, type: InternalApi.EphemeralEnvironments.StateChangeResult, enum: true)
  field(:TriggererType, 7, type: :string)
  field(:trigger_id, 8, type: :string)
  field(:execution_pipeline_id, 9, type: :string)
  field(:execution_workflow_id, 10, type: :string)
  field(:started_at, 11, type: Google.Protobuf.Timestamp)
  field(:finished_at, 12, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.EphemeralEnvironments.StageType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:STAGE_TYPE_UNSPECIFIED, 0)
  field(:STAGE_TYPE_PROVISION, 1)
  field(:STAGE_TYPE_DEPLOY, 2)
  field(:STAGE_TYPE_DEPROVISION, 3)
end

defmodule InternalApi.EphemeralEnvironments.InstanceState do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

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
  use Protobuf, enum: true, syntax: :proto3

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
  use Protobuf, enum: true, syntax: :proto3

  field(:STATE_CHANGE_RESULT_UNSPECIFIED, 0)
  field(:STATE_CHANGE_RESULT_PASSED, 1)
  field(:STATE_CHANGE_RESULT_PENDING, 2)
  field(:STATE_CHANGE_RESULT_FAILED, 3)
end

defmodule InternalApi.EphemeralEnvironments.TriggererType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:TRIGGERER_TYPE_UNSPECIFIED, 0)
  field(:TRIGGERER_TYPE_USER, 1)
  field(:TRIGGERER_TYPE_AUTOMATION_RULE, 2)
end

defmodule InternalApi.EphemeralEnvironments.TypeState do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:TYPE_STATE_UNSPECIFIED, 0)
  field(:TYPE_STATE_DRAFT, 1)
  field(:TYPE_STATE_READY, 2)
  field(:TYPE_STATE_CORDONED, 3)
  field(:TYPE_STATE_DELETED, 4)
end

defmodule InternalApi.EphemeralEnvironments.EphemeralEnvironments.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.EphemeralEnvironments.EphemeralEnvironments"

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
