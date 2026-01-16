defmodule InternalApi.Gofer.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          targets: [InternalApi.Gofer.Target.t()],
          branch_name: String.t(),
          prev_ppl_artefact_ids: [String.t()],
          label: String.t(),
          git_ref_type: integer,
          project_id: String.t(),
          commit_sha: String.t(),
          working_dir: String.t(),
          commit_range: String.t(),
          yml_file_name: String.t(),
          pr_base: String.t(),
          pr_sha: String.t()
        }
  defstruct [
    :pipeline_id,
    :targets,
    :branch_name,
    :prev_ppl_artefact_ids,
    :label,
    :git_ref_type,
    :project_id,
    :commit_sha,
    :working_dir,
    :commit_range,
    :yml_file_name,
    :pr_base,
    :pr_sha
  ]

  field(:pipeline_id, 1, type: :string)
  field(:targets, 2, repeated: true, type: InternalApi.Gofer.Target)
  field(:branch_name, 4, type: :string)
  field(:prev_ppl_artefact_ids, 5, repeated: true, type: :string)
  field(:label, 6, type: :string)
  field(:git_ref_type, 7, type: InternalApi.Gofer.GitRefType, enum: true)
  field(:project_id, 8, type: :string)
  field(:commit_sha, 9, type: :string)
  field(:working_dir, 10, type: :string)
  field(:commit_range, 11, type: :string)
  field(:yml_file_name, 12, type: :string)
  field(:pr_base, 13, type: :string)
  field(:pr_sha, 14, type: :string)
end

defmodule InternalApi.Gofer.Target do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          pipeline_path: String.t(),
          auto_trigger_on: [InternalApi.Gofer.AutoTriggerCond.t()],
          parameter_env_vars: [InternalApi.Gofer.ParamEnvVar.t()],
          auto_promote_when: String.t(),
          deployment_target: String.t()
        }
  defstruct [
    :name,
    :pipeline_path,
    :auto_trigger_on,
    :parameter_env_vars,
    :auto_promote_when,
    :deployment_target
  ]

  field(:name, 1, type: :string)
  field(:pipeline_path, 2, type: :string)
  field(:auto_trigger_on, 5, repeated: true, type: InternalApi.Gofer.AutoTriggerCond)
  field(:parameter_env_vars, 6, repeated: true, type: InternalApi.Gofer.ParamEnvVar)
  field(:auto_promote_when, 7, type: :string)
  field(:deployment_target, 8, type: :string)
end

defmodule InternalApi.Gofer.ParamEnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          options: [String.t()],
          required: boolean,
          default_value: String.t(),
          description: String.t()
        }
  defstruct [:name, :options, :required, :default_value, :description]

  field(:name, 1, type: :string)
  field(:options, 2, repeated: true, type: :string)
  field(:required, 3, type: :bool)
  field(:default_value, 4, type: :string)
  field(:description, 5, type: :string)
end

defmodule InternalApi.Gofer.AutoTriggerCond do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          result: String.t(),
          branch: [String.t()],
          result_reason: String.t(),
          labels: [String.t()],
          label_patterns: [String.t()]
        }
  defstruct [:result, :branch, :result_reason, :labels, :label_patterns]

  field(:result, 1, type: :string)
  field(:branch, 2, repeated: true, type: :string)
  field(:result_reason, 3, type: :string)
  field(:labels, 4, repeated: true, type: :string)
  field(:label_patterns, 5, repeated: true, type: :string)
end

defmodule InternalApi.Gofer.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Gofer.ResponseStatus.t(),
          switch_id: String.t()
        }
  defstruct [:response_status, :switch_id]

  field(:response_status, 1, type: InternalApi.Gofer.ResponseStatus)
  field(:switch_id, 2, type: :string)
end

defmodule InternalApi.Gofer.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          switch_id: String.t(),
          events_per_target: integer,
          requester_id: String.t()
        }
  defstruct [:switch_id, :events_per_target, :requester_id]

  field(:switch_id, 1, type: :string)
  field(:events_per_target, 2, type: :int32)
  field(:requester_id, 3, type: :string)
end

defmodule InternalApi.Gofer.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Gofer.ResponseStatus.t(),
          switch_id: String.t(),
          ppl_id: String.t(),
          pipeline_done: boolean,
          pipeline_result: String.t(),
          targets: [InternalApi.Gofer.TargetDescription.t()],
          pipeline_result_reason: String.t()
        }
  defstruct [
    :response_status,
    :switch_id,
    :ppl_id,
    :pipeline_done,
    :pipeline_result,
    :targets,
    :pipeline_result_reason
  ]

  field(:response_status, 1, type: InternalApi.Gofer.ResponseStatus)
  field(:switch_id, 2, type: :string)
  field(:ppl_id, 3, type: :string)
  field(:pipeline_done, 4, type: :bool)
  field(:pipeline_result, 5, type: :string)
  field(:targets, 6, repeated: true, type: InternalApi.Gofer.TargetDescription)
  field(:pipeline_result_reason, 7, type: :string)
end

defmodule InternalApi.Gofer.TargetDescription do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          pipeline_path: String.t(),
          trigger_events: [InternalApi.Gofer.TriggerEvent.t()],
          auto_trigger_on: [InternalApi.Gofer.AutoTriggerCond.t()],
          parameter_env_vars: [InternalApi.Gofer.ParamEnvVar.t()],
          dt_description: InternalApi.Gofer.DeploymentTargetDescription.t()
        }
  defstruct [
    :name,
    :pipeline_path,
    :trigger_events,
    :auto_trigger_on,
    :parameter_env_vars,
    :dt_description
  ]

  field(:name, 1, type: :string)
  field(:pipeline_path, 2, type: :string)
  field(:trigger_events, 4, repeated: true, type: InternalApi.Gofer.TriggerEvent)
  field(:auto_trigger_on, 6, repeated: true, type: InternalApi.Gofer.AutoTriggerCond)
  field(:parameter_env_vars, 7, repeated: true, type: InternalApi.Gofer.ParamEnvVar)
  field(:dt_description, 8, type: InternalApi.Gofer.DeploymentTargetDescription)
end

defmodule InternalApi.Gofer.DeploymentTargetDescription do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target_id: String.t(),
          target_name: String.t(),
          access: InternalApi.Gofer.DeploymentTargetDescription.Access.t()
        }
  defstruct [:target_id, :target_name, :access]

  field(:target_id, 1, type: :string)
  field(:target_name, 2, type: :string)
  field(:access, 3, type: InternalApi.Gofer.DeploymentTargetDescription.Access)
end

defmodule InternalApi.Gofer.DeploymentTargetDescription.Access do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed: boolean,
          reason: integer,
          message: String.t()
        }
  defstruct [:allowed, :reason, :message]

  field(:allowed, 1, type: :bool)
  field(:reason, 2, type: InternalApi.Gofer.DeploymentTargetDescription.Access.Reason, enum: true)
  field(:message, 3, type: :string)
end

defmodule InternalApi.Gofer.DeploymentTargetDescription.Access.Reason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:INTERNAL_ERROR, 0)
  field(:NO_REASON, 1)
  field(:SYNCING_TARGET, 2)
  field(:CORRUPTED_TARGET, 3)
  field(:BANNED_SUBJECT, 4)
  field(:BANNED_OBJECT, 5)
  field(:CORDONED_TARGET, 6)
end

defmodule InternalApi.Gofer.TriggerEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          target_name: String.t(),
          triggered_at: Google.Protobuf.Timestamp.t(),
          auto_triggered: boolean,
          triggered_by: String.t(),
          override: boolean,
          processed: boolean,
          processing_result: integer,
          scheduled_at: Google.Protobuf.Timestamp.t(),
          scheduled_pipeline_id: String.t(),
          error_response: String.t(),
          env_variables: [InternalApi.Gofer.EnvVariable.t()]
        }
  defstruct [
    :target_name,
    :triggered_at,
    :auto_triggered,
    :triggered_by,
    :override,
    :processed,
    :processing_result,
    :scheduled_at,
    :scheduled_pipeline_id,
    :error_response,
    :env_variables
  ]

  field(:target_name, 1, type: :string)
  field(:triggered_at, 2, type: Google.Protobuf.Timestamp)
  field(:auto_triggered, 3, type: :bool)
  field(:triggered_by, 4, type: :string)
  field(:override, 5, type: :bool)
  field(:processed, 6, type: :bool)
  field(:processing_result, 7, type: InternalApi.Gofer.TriggerEvent.ProcessingResult, enum: true)
  field(:scheduled_at, 8, type: Google.Protobuf.Timestamp)
  field(:scheduled_pipeline_id, 9, type: :string)
  field(:error_response, 10, type: :string)
  field(:env_variables, 11, repeated: true, type: InternalApi.Gofer.EnvVariable)
end

defmodule InternalApi.Gofer.TriggerEvent.ProcessingResult do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PASSED, 0)
  field(:FAILED, 1)
end

defmodule InternalApi.Gofer.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          switch_ids: [String.t()],
          events_per_target: integer,
          requester_id: String.t()
        }
  defstruct [:switch_ids, :events_per_target, :requester_id]

  field(:switch_ids, 1, repeated: true, type: :string)
  field(:events_per_target, 2, type: :int32)
  field(:requester_id, 3, type: :string)
end

defmodule InternalApi.Gofer.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Gofer.ResponseStatus.t(),
          switches: [InternalApi.Gofer.SwitchDetails.t()]
        }
  defstruct [:response_status, :switches]

  field(:response_status, 1, type: InternalApi.Gofer.ResponseStatus)
  field(:switches, 2, repeated: true, type: InternalApi.Gofer.SwitchDetails)
end

defmodule InternalApi.Gofer.SwitchDetails do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          switch_id: String.t(),
          ppl_id: String.t(),
          pipeline_done: boolean,
          pipeline_result: String.t(),
          pipeline_result_reason: String.t(),
          targets: [InternalApi.Gofer.TargetDescription.t()]
        }
  defstruct [
    :switch_id,
    :ppl_id,
    :pipeline_done,
    :pipeline_result,
    :pipeline_result_reason,
    :targets
  ]

  field(:switch_id, 1, type: :string)
  field(:ppl_id, 2, type: :string)
  field(:pipeline_done, 3, type: :bool)
  field(:pipeline_result, 4, type: :string)
  field(:pipeline_result_reason, 5, type: :string)
  field(:targets, 6, repeated: true, type: InternalApi.Gofer.TargetDescription)
end

defmodule InternalApi.Gofer.ListTriggerEventsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          switch_id: String.t(),
          target_name: String.t(),
          page: integer,
          page_size: integer
        }
  defstruct [:switch_id, :target_name, :page, :page_size]

  field(:switch_id, 1, type: :string)
  field(:target_name, 2, type: :string)
  field(:page, 3, type: :int32)
  field(:page_size, 4, type: :int32)
end

defmodule InternalApi.Gofer.ListTriggerEventsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Gofer.ResponseStatus.t(),
          trigger_events: [InternalApi.Gofer.TriggerEvent.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [
    :response_status,
    :trigger_events,
    :page_number,
    :page_size,
    :total_entries,
    :total_pages
  ]

  field(:response_status, 1, type: InternalApi.Gofer.ResponseStatus)
  field(:trigger_events, 2, repeated: true, type: InternalApi.Gofer.TriggerEvent)
  field(:page_number, 3, type: :int32)
  field(:page_size, 4, type: :int32)
  field(:total_entries, 5, type: :int32)
  field(:total_pages, 6, type: :int32)
end

defmodule InternalApi.Gofer.PipelineDoneRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          switch_id: String.t(),
          result: String.t(),
          result_reason: String.t()
        }
  defstruct [:switch_id, :result, :result_reason]

  field(:switch_id, 1, type: :string)
  field(:result, 2, type: :string)
  field(:result_reason, 3, type: :string)
end

defmodule InternalApi.Gofer.PipelineDoneResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Gofer.ResponseStatus.t()
        }
  defstruct [:response_status]

  field(:response_status, 1, type: InternalApi.Gofer.ResponseStatus)
end

defmodule InternalApi.Gofer.TriggerRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          switch_id: String.t(),
          target_name: String.t(),
          triggered_by: String.t(),
          override: boolean,
          request_token: String.t(),
          env_variables: [InternalApi.Gofer.EnvVariable.t()]
        }
  defstruct [:switch_id, :target_name, :triggered_by, :override, :request_token, :env_variables]

  field(:switch_id, 1, type: :string)
  field(:target_name, 2, type: :string)
  field(:triggered_by, 3, type: :string)
  field(:override, 4, type: :bool)
  field(:request_token, 5, type: :string)
  field(:env_variables, 6, repeated: true, type: InternalApi.Gofer.EnvVariable)
end

defmodule InternalApi.Gofer.EnvVariable do
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

defmodule InternalApi.Gofer.TriggerResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Gofer.ResponseStatus.t()
        }
  defstruct [:response_status]

  field(:response_status, 1, type: InternalApi.Gofer.ResponseStatus)
end

defmodule InternalApi.Gofer.VersionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Gofer.VersionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          version: String.t()
        }
  defstruct [:version]

  field(:version, 1, type: :string)
end

defmodule InternalApi.Gofer.ResponseStatus do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: integer,
          message: String.t()
        }
  defstruct [:code, :message]

  field(:code, 1, type: InternalApi.Gofer.ResponseStatus.ResponseCode, enum: true)
  field(:message, 2, type: :string)
end

defmodule InternalApi.Gofer.ResponseStatus.ResponseCode do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:OK, 0)
  field(:BAD_PARAM, 1)
  field(:NOT_FOUND, 2)
  field(:RESULT_CHANGED, 3)
  field(:FAILED, 4)
  field(:REFUSED, 5)
  field(:RESULT_REASON_CHANGED, 6)
  field(:MALFORMED, 7)
end

defmodule InternalApi.Gofer.GitRefType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BRANCH, 0)
  field(:TAG, 1)
  field(:PR, 2)
end

defmodule InternalApi.Gofer.Switch.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Gofer.Switch"

  rpc(:Create, InternalApi.Gofer.CreateRequest, InternalApi.Gofer.CreateResponse)
  rpc(:Describe, InternalApi.Gofer.DescribeRequest, InternalApi.Gofer.DescribeResponse)

  rpc(
    :DescribeMany,
    InternalApi.Gofer.DescribeManyRequest,
    InternalApi.Gofer.DescribeManyResponse
  )

  rpc(
    :ListTriggerEvents,
    InternalApi.Gofer.ListTriggerEventsRequest,
    InternalApi.Gofer.ListTriggerEventsResponse
  )

  rpc(
    :PipelineDone,
    InternalApi.Gofer.PipelineDoneRequest,
    InternalApi.Gofer.PipelineDoneResponse
  )

  rpc(:Trigger, InternalApi.Gofer.TriggerRequest, InternalApi.Gofer.TriggerResponse)
  rpc(:Version, InternalApi.Gofer.VersionRequest, InternalApi.Gofer.VersionResponse)
end

defmodule InternalApi.Gofer.Switch.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Gofer.Switch.Service
end
