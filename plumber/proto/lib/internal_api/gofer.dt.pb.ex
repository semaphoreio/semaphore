defmodule InternalApi.Gofer.DeploymentTargets.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:project_id, :requester_id]

  field(:project_id, 1, type: :string)
  field(:requester_id, 2, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          targets: [InternalApi.Gofer.DeploymentTargets.DeploymentTarget.t()]
        }
  defstruct [:targets]

  field(:targets, 1, repeated: true, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget)
end

defmodule InternalApi.Gofer.DeploymentTargets.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          target_name: String.t(),
          target_id: String.t()
        }
  defstruct [:project_id, :target_name, :target_id]

  field(:project_id, 1, type: :string)
  field(:target_name, 2, type: :string)
  field(:target_id, 3, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Gofer.DeploymentTargets.DeploymentTarget.t()
        }
  defstruct [:target]

  field(:target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget)
end

defmodule InternalApi.Gofer.DeploymentTargets.VerifyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target_id: String.t(),
          triggerer: String.t(),
          git_ref_type: integer,
          git_ref_label: String.t()
        }
  defstruct [:target_id, :triggerer, :git_ref_type, :git_ref_label]

  field(:target_id, 1, type: :string)
  field(:triggerer, 2, type: :string)

  field(
    :git_ref_type,
    3,
    type: InternalApi.Gofer.DeploymentTargets.VerifyRequest.GitRefType,
    enum: true
  )

  field(:git_ref_label, 4, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.VerifyRequest.GitRefType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BRANCH, 0)
  field(:TAG, 1)
  field(:PR, 2)
end

defmodule InternalApi.Gofer.DeploymentTargets.VerifyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: integer
        }
  defstruct [:status]

  field(:status, 1, type: InternalApi.Gofer.DeploymentTargets.VerifyResponse.Status, enum: true)
end

defmodule InternalApi.Gofer.DeploymentTargets.VerifyResponse.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:SYNCING_TARGET, 0)
  field(:ACCESS_GRANTED, 1)
  field(:BANNED_SUBJECT, 2)
  field(:BANNED_OBJECT, 3)
  field(:CORDONED_TARGET, 4)
  field(:CORRUPTED_TARGET, 5)
end

defmodule InternalApi.Gofer.DeploymentTargets.HistoryRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target_id: String.t(),
          cursor_type: integer,
          cursor_value: non_neg_integer,
          filters: InternalApi.Gofer.DeploymentTargets.HistoryRequest.Filters.t(),
          requester_id: String.t()
        }
  defstruct [:target_id, :cursor_type, :cursor_value, :filters, :requester_id]

  field(:target_id, 1, type: :string)

  field(
    :cursor_type,
    2,
    type: InternalApi.Gofer.DeploymentTargets.HistoryRequest.CursorType,
    enum: true
  )

  field(:cursor_value, 3, type: :uint64)
  field(:filters, 4, type: InternalApi.Gofer.DeploymentTargets.HistoryRequest.Filters)
  field(:requester_id, 5, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.HistoryRequest.Filters do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          git_ref_type: String.t(),
          git_ref_label: String.t(),
          triggered_by: String.t(),
          parameter1: String.t(),
          parameter2: String.t(),
          parameter3: String.t()
        }
  defstruct [:git_ref_type, :git_ref_label, :triggered_by, :parameter1, :parameter2, :parameter3]

  field(:git_ref_type, 1, type: :string)
  field(:git_ref_label, 2, type: :string)
  field(:triggered_by, 3, type: :string)
  field(:parameter1, 4, type: :string)
  field(:parameter2, 5, type: :string)
  field(:parameter3, 6, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.HistoryRequest.CursorType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:FIRST, 0)
  field(:AFTER, 1)
  field(:BEFORE, 2)
end

defmodule InternalApi.Gofer.DeploymentTargets.HistoryResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          deployments: [InternalApi.Gofer.DeploymentTargets.Deployment.t()],
          cursor_before: non_neg_integer,
          cursor_after: non_neg_integer
        }
  defstruct [:deployments, :cursor_before, :cursor_after]

  field(:deployments, 1, repeated: true, type: InternalApi.Gofer.DeploymentTargets.Deployment)
  field(:cursor_before, 2, type: :uint64)
  field(:cursor_after, 3, type: :uint64)
end

defmodule InternalApi.Gofer.DeploymentTargets.CordonRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target_id: String.t(),
          cordoned: boolean
        }
  defstruct [:target_id, :cordoned]

  field(:target_id, 1, type: :string)
  field(:cordoned, 2, type: :bool)
end

defmodule InternalApi.Gofer.DeploymentTargets.CordonResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target_id: String.t(),
          cordoned: boolean
        }
  defstruct [:target_id, :cordoned]

  field(:target_id, 1, type: :string)
  field(:cordoned, 2, type: :bool)
end

defmodule InternalApi.Gofer.DeploymentTargets.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Gofer.DeploymentTargets.DeploymentTarget.t(),
          secret: InternalApi.Gofer.DeploymentTargets.EncryptedSecretData.t(),
          unique_token: String.t(),
          requester_id: String.t()
        }
  defstruct [:target, :secret, :unique_token, :requester_id]

  field(:target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget)
  field(:secret, 2, type: InternalApi.Gofer.DeploymentTargets.EncryptedSecretData)
  field(:unique_token, 3, type: :string)
  field(:requester_id, 4, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Gofer.DeploymentTargets.DeploymentTarget.t()
        }
  defstruct [:target]

  field(:target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget)
end

defmodule InternalApi.Gofer.DeploymentTargets.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Gofer.DeploymentTargets.DeploymentTarget.t(),
          secret: InternalApi.Gofer.DeploymentTargets.EncryptedSecretData.t(),
          unique_token: String.t(),
          requester_id: String.t()
        }
  defstruct [:target, :secret, :unique_token, :requester_id]

  field(:target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget)
  field(:secret, 2, type: InternalApi.Gofer.DeploymentTargets.EncryptedSecretData)
  field(:unique_token, 3, type: :string)
  field(:requester_id, 4, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target: InternalApi.Gofer.DeploymentTargets.DeploymentTarget.t()
        }
  defstruct [:target]

  field(:target, 1, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget)
end

defmodule InternalApi.Gofer.DeploymentTargets.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target_id: String.t(),
          requester_id: String.t(),
          unique_token: String.t()
        }
  defstruct [:target_id, :requester_id, :unique_token]

  field(:target_id, 1, type: :string)
  field(:requester_id, 2, type: :string)
  field(:unique_token, 3, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target_id: String.t()
        }
  defstruct [:target_id]

  field(:target_id, 1, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.DeploymentTarget do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          url: String.t(),
          organization_id: String.t(),
          project_id: String.t(),
          created_by: String.t(),
          updated_by: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t(),
          state: integer,
          state_message: String.t(),
          subject_rules: [InternalApi.Gofer.DeploymentTargets.SubjectRule.t()],
          object_rules: [InternalApi.Gofer.DeploymentTargets.ObjectRule.t()],
          last_deployment: InternalApi.Gofer.DeploymentTargets.Deployment.t(),
          cordoned: boolean,
          bookmark_parameter1: String.t(),
          bookmark_parameter2: String.t(),
          bookmark_parameter3: String.t(),
          secret_name: String.t()
        }
  defstruct [
    :id,
    :name,
    :description,
    :url,
    :organization_id,
    :project_id,
    :created_by,
    :updated_by,
    :created_at,
    :updated_at,
    :state,
    :state_message,
    :subject_rules,
    :object_rules,
    :last_deployment,
    :cordoned,
    :bookmark_parameter1,
    :bookmark_parameter2,
    :bookmark_parameter3,
    :secret_name
  ]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:url, 4, type: :string)
  field(:organization_id, 5, type: :string)
  field(:project_id, 6, type: :string)
  field(:created_by, 7, type: :string)
  field(:updated_by, 8, type: :string)
  field(:created_at, 9, type: Google.Protobuf.Timestamp)
  field(:updated_at, 10, type: Google.Protobuf.Timestamp)
  field(:state, 11, type: InternalApi.Gofer.DeploymentTargets.DeploymentTarget.State, enum: true)
  field(:state_message, 12, type: :string)
  field(:subject_rules, 13, repeated: true, type: InternalApi.Gofer.DeploymentTargets.SubjectRule)
  field(:object_rules, 14, repeated: true, type: InternalApi.Gofer.DeploymentTargets.ObjectRule)
  field(:last_deployment, 15, type: InternalApi.Gofer.DeploymentTargets.Deployment)
  field(:cordoned, 16, type: :bool)
  field(:bookmark_parameter1, 17, type: :string)
  field(:bookmark_parameter2, 18, type: :string)
  field(:bookmark_parameter3, 19, type: :string)
  field(:secret_name, 20, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.DeploymentTarget.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:SYNCING, 0)
  field(:USABLE, 1)
  field(:UNUSABLE, 2)
  field(:CORDONED, 3)
end

defmodule InternalApi.Gofer.DeploymentTargets.Deployment do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          target_id: String.t(),
          prev_pipeline_id: String.t(),
          pipeline_id: String.t(),
          triggered_by: String.t(),
          triggered_at: Google.Protobuf.Timestamp.t(),
          state: integer,
          state_message: String.t(),
          switch_id: String.t(),
          target_name: String.t(),
          env_vars: [InternalApi.Gofer.DeploymentTargets.Deployment.EnvVar.t()],
          can_requester_rerun: boolean
        }
  defstruct [
    :id,
    :target_id,
    :prev_pipeline_id,
    :pipeline_id,
    :triggered_by,
    :triggered_at,
    :state,
    :state_message,
    :switch_id,
    :target_name,
    :env_vars,
    :can_requester_rerun
  ]

  field(:id, 1, type: :string)
  field(:target_id, 2, type: :string)
  field(:prev_pipeline_id, 3, type: :string)
  field(:pipeline_id, 4, type: :string)
  field(:triggered_by, 5, type: :string)
  field(:triggered_at, 6, type: Google.Protobuf.Timestamp)
  field(:state, 7, type: InternalApi.Gofer.DeploymentTargets.Deployment.State, enum: true)
  field(:state_message, 8, type: :string)
  field(:switch_id, 9, type: :string)
  field(:target_name, 10, type: :string)

  field(
    :env_vars,
    11,
    repeated: true,
    type: InternalApi.Gofer.DeploymentTargets.Deployment.EnvVar
  )

  field(:can_requester_rerun, 12, type: :bool)
end

defmodule InternalApi.Gofer.DeploymentTargets.Deployment.EnvVar do
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

defmodule InternalApi.Gofer.DeploymentTargets.Deployment.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PENDING, 0)
  field(:STARTED, 1)
  field(:FAILED, 2)
end

defmodule InternalApi.Gofer.DeploymentTargets.SubjectRule do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          subject_id: String.t()
        }
  defstruct [:type, :subject_id]

  field(:type, 1, type: InternalApi.Gofer.DeploymentTargets.SubjectRule.Type, enum: true)
  field(:subject_id, 2, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.SubjectRule.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:USER, 0)
  field(:ROLE, 1)
  field(:GROUP, 2)
  field(:AUTO, 3)
  field(:ANY, 4)
end

defmodule InternalApi.Gofer.DeploymentTargets.ObjectRule do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          match_mode: integer,
          pattern: String.t()
        }
  defstruct [:type, :match_mode, :pattern]

  field(:type, 1, type: InternalApi.Gofer.DeploymentTargets.ObjectRule.Type, enum: true)
  field(:match_mode, 2, type: InternalApi.Gofer.DeploymentTargets.ObjectRule.Mode, enum: true)
  field(:pattern, 3, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.ObjectRule.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BRANCH, 0)
  field(:TAG, 1)
  field(:PR, 2)
end

defmodule InternalApi.Gofer.DeploymentTargets.ObjectRule.Mode do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ALL, 0)
  field(:EXACT, 1)
  field(:REGEX, 2)
end

defmodule InternalApi.Gofer.DeploymentTargets.EncryptedSecretData do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          key_id: String.t(),
          aes256_key: String.t(),
          init_vector: String.t(),
          payload: String.t()
        }
  defstruct [:key_id, :aes256_key, :init_vector, :payload]

  field(:key_id, 2, type: :string)
  field(:aes256_key, 3, type: :string)
  field(:init_vector, 4, type: :string)
  field(:payload, 5, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Gofer.DeploymentTargets.DeploymentTargets"

  rpc(
    :List,
    InternalApi.Gofer.DeploymentTargets.ListRequest,
    InternalApi.Gofer.DeploymentTargets.ListResponse
  )

  rpc(
    :Describe,
    InternalApi.Gofer.DeploymentTargets.DescribeRequest,
    InternalApi.Gofer.DeploymentTargets.DescribeResponse
  )

  rpc(
    :Verify,
    InternalApi.Gofer.DeploymentTargets.VerifyRequest,
    InternalApi.Gofer.DeploymentTargets.VerifyResponse
  )

  rpc(
    :History,
    InternalApi.Gofer.DeploymentTargets.HistoryRequest,
    InternalApi.Gofer.DeploymentTargets.HistoryResponse
  )

  rpc(
    :Cordon,
    InternalApi.Gofer.DeploymentTargets.CordonRequest,
    InternalApi.Gofer.DeploymentTargets.CordonResponse
  )

  rpc(
    :Create,
    InternalApi.Gofer.DeploymentTargets.CreateRequest,
    InternalApi.Gofer.DeploymentTargets.CreateResponse
  )

  rpc(
    :Update,
    InternalApi.Gofer.DeploymentTargets.UpdateRequest,
    InternalApi.Gofer.DeploymentTargets.UpdateResponse
  )

  rpc(
    :Delete,
    InternalApi.Gofer.DeploymentTargets.DeleteRequest,
    InternalApi.Gofer.DeploymentTargets.DeleteResponse
  )
end

defmodule InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Gofer.DeploymentTargets.DeploymentTargets.Service
end
