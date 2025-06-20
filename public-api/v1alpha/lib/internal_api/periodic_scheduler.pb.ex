defmodule InternalApi.PeriodicScheduler.ApplyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          requester_id: String.t(),
          organization_id: String.t(),
          yml_definition: String.t()
        }
  defstruct [:requester_id, :organization_id, :yml_definition]

  field(:requester_id, 1, type: :string)
  field(:organization_id, 2, type: :string)
  field(:yml_definition, 3, type: :string)
end

defmodule InternalApi.PeriodicScheduler.ApplyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          id: String.t()
        }
  defstruct [:status, :id]

  field(:status, 1, type: InternalApi.Status)
  field(:id, 2, type: :string)
end

defmodule InternalApi.PeriodicScheduler.PersistRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          recurring: boolean,
          state: integer,
          organization_id: String.t(),
          project_name: String.t(),
          requester_id: String.t(),
          branch: String.t(),
          pipeline_file: String.t(),
          at: String.t(),
          parameters: [InternalApi.PeriodicScheduler.Periodic.Parameter.t()],
          project_id: String.t()
        }
  defstruct [
    :id,
    :name,
    :description,
    :recurring,
    :state,
    :organization_id,
    :project_name,
    :requester_id,
    :branch,
    :pipeline_file,
    :at,
    :parameters,
    :project_id
  ]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:recurring, 4, type: :bool)
  field(:state, 5, type: InternalApi.PeriodicScheduler.PersistRequest.ScheduleState, enum: true)
  field(:organization_id, 6, type: :string)
  field(:project_name, 7, type: :string)
  field(:requester_id, 8, type: :string)
  field(:branch, 9, type: :string)
  field(:pipeline_file, 10, type: :string)
  field(:at, 11, type: :string)
  field(:parameters, 12, repeated: true, type: InternalApi.PeriodicScheduler.Periodic.Parameter)
  field(:project_id, 13, type: :string)
end

defmodule InternalApi.PeriodicScheduler.PersistRequest.ScheduleState do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:UNCHANGED, 0)
  field(:ACTIVE, 1)
  field(:PAUSED, 2)
end

defmodule InternalApi.PeriodicScheduler.PersistResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          periodic: InternalApi.PeriodicScheduler.Periodic.t()
        }
  defstruct [:status, :periodic]

  field(:status, 1, type: InternalApi.Status)
  field(:periodic, 2, type: InternalApi.PeriodicScheduler.Periodic)
end

defmodule InternalApi.PeriodicScheduler.PauseRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          requester: String.t()
        }
  defstruct [:id, :requester]

  field(:id, 1, type: :string)
  field(:requester, 2, type: :string)
end

defmodule InternalApi.PeriodicScheduler.PauseResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t()
        }
  defstruct [:status]

  field(:status, 1, type: InternalApi.Status)
end

defmodule InternalApi.PeriodicScheduler.UnpauseRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          requester: String.t()
        }
  defstruct [:id, :requester]

  field(:id, 1, type: :string)
  field(:requester, 2, type: :string)
end

defmodule InternalApi.PeriodicScheduler.UnpauseResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t()
        }
  defstruct [:status]

  field(:status, 1, type: InternalApi.Status)
end

defmodule InternalApi.PeriodicScheduler.RunNowRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          requester: String.t(),
          branch: String.t(),
          pipeline_file: String.t(),
          parameter_values: [InternalApi.PeriodicScheduler.ParameterValue.t()]
        }
  defstruct [:id, :requester, :branch, :pipeline_file, :parameter_values]

  field(:id, 1, type: :string)
  field(:requester, 2, type: :string)
  field(:branch, 3, type: :string)
  field(:pipeline_file, 4, type: :string)
  field(:parameter_values, 5, repeated: true, type: InternalApi.PeriodicScheduler.ParameterValue)
end

defmodule InternalApi.PeriodicScheduler.RunNowResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          periodic: InternalApi.PeriodicScheduler.Periodic.t(),
          triggers: [InternalApi.PeriodicScheduler.Trigger.t()],
          trigger: InternalApi.PeriodicScheduler.Trigger.t()
        }
  defstruct [:status, :periodic, :triggers, :trigger]

  field(:status, 1, type: InternalApi.Status)
  field(:periodic, 2, type: InternalApi.PeriodicScheduler.Periodic)
  field(:triggers, 3, repeated: true, type: InternalApi.PeriodicScheduler.Trigger)
  field(:trigger, 4, type: InternalApi.PeriodicScheduler.Trigger)
end

defmodule InternalApi.PeriodicScheduler.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }
  defstruct [:id]

  field(:id, 1, type: :string)
end

defmodule InternalApi.PeriodicScheduler.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          periodic: InternalApi.PeriodicScheduler.Periodic.t(),
          triggers: [InternalApi.PeriodicScheduler.Trigger.t()]
        }
  defstruct [:status, :periodic, :triggers]

  field(:status, 1, type: InternalApi.Status)
  field(:periodic, 2, type: InternalApi.PeriodicScheduler.Periodic)
  field(:triggers, 3, repeated: true, type: InternalApi.PeriodicScheduler.Trigger)
end

defmodule InternalApi.PeriodicScheduler.Periodic do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          project_id: String.t(),
          branch: String.t(),
          at: String.t(),
          pipeline_file: String.t(),
          requester_id: String.t(),
          updated_at: Google.Protobuf.Timestamp.t(),
          suspended: boolean,
          paused: boolean,
          pause_toggled_by: String.t(),
          pause_toggled_at: Google.Protobuf.Timestamp.t(),
          inserted_at: Google.Protobuf.Timestamp.t(),
          recurring: boolean,
          parameters: [InternalApi.PeriodicScheduler.Periodic.Parameter.t()],
          description: String.t(),
          organization_id: String.t()
        }
  defstruct [
    :id,
    :name,
    :project_id,
    :branch,
    :at,
    :pipeline_file,
    :requester_id,
    :updated_at,
    :suspended,
    :paused,
    :pause_toggled_by,
    :pause_toggled_at,
    :inserted_at,
    :recurring,
    :parameters,
    :description,
    :organization_id
  ]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:project_id, 3, type: :string)
  field(:branch, 4, type: :string)
  field(:at, 5, type: :string)
  field(:pipeline_file, 6, type: :string)
  field(:requester_id, 7, type: :string)
  field(:updated_at, 8, type: Google.Protobuf.Timestamp)
  field(:suspended, 9, type: :bool)
  field(:paused, 10, type: :bool)
  field(:pause_toggled_by, 11, type: :string)
  field(:pause_toggled_at, 12, type: Google.Protobuf.Timestamp)
  field(:inserted_at, 13, type: Google.Protobuf.Timestamp)
  field(:recurring, 14, type: :bool)
  field(:parameters, 15, repeated: true, type: InternalApi.PeriodicScheduler.Periodic.Parameter)
  field(:description, 16, type: :string)
  field(:organization_id, 17, type: :string)
end

defmodule InternalApi.PeriodicScheduler.Periodic.Parameter do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          required: boolean,
          description: String.t(),
          default_value: String.t(),
          options: [String.t()]
        }
  defstruct [:name, :required, :description, :default_value, :options]

  field(:name, 1, type: :string)
  field(:required, 2, type: :bool)
  field(:description, 3, type: :string)
  field(:default_value, 4, type: :string)
  field(:options, 5, repeated: true, type: :string)
end

defmodule InternalApi.PeriodicScheduler.Trigger do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          triggered_at: Google.Protobuf.Timestamp.t(),
          project_id: String.t(),
          branch: String.t(),
          pipeline_file: String.t(),
          scheduling_status: String.t(),
          scheduled_workflow_id: String.t(),
          scheduled_at: Google.Protobuf.Timestamp.t(),
          error_description: String.t(),
          run_now_requester_id: String.t(),
          periodic_id: String.t(),
          parameter_values: [InternalApi.PeriodicScheduler.ParameterValue.t()]
        }
  defstruct [
    :triggered_at,
    :project_id,
    :branch,
    :pipeline_file,
    :scheduling_status,
    :scheduled_workflow_id,
    :scheduled_at,
    :error_description,
    :run_now_requester_id,
    :periodic_id,
    :parameter_values
  ]

  field(:triggered_at, 1, type: Google.Protobuf.Timestamp)
  field(:project_id, 2, type: :string)
  field(:branch, 3, type: :string)
  field(:pipeline_file, 4, type: :string)
  field(:scheduling_status, 5, type: :string)
  field(:scheduled_workflow_id, 6, type: :string)
  field(:scheduled_at, 7, type: Google.Protobuf.Timestamp)
  field(:error_description, 8, type: :string)
  field(:run_now_requester_id, 9, type: :string)
  field(:periodic_id, 10, type: :string)
  field(:parameter_values, 11, repeated: true, type: InternalApi.PeriodicScheduler.ParameterValue)
end

defmodule InternalApi.PeriodicScheduler.ParameterValue do
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

defmodule InternalApi.PeriodicScheduler.LatestTriggersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          periodic_ids: [String.t()]
        }
  defstruct [:periodic_ids]

  field(:periodic_ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.PeriodicScheduler.LatestTriggersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          triggers: [InternalApi.PeriodicScheduler.Trigger.t()]
        }
  defstruct [:status, :triggers]

  field(:status, 1, type: InternalApi.Status)
  field(:triggers, 2, repeated: true, type: InternalApi.PeriodicScheduler.Trigger)
end

defmodule InternalApi.PeriodicScheduler.HistoryRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          periodic_id: String.t(),
          cursor_type: integer,
          cursor_value: non_neg_integer,
          filters: InternalApi.PeriodicScheduler.HistoryRequest.Filters.t()
        }
  defstruct [:periodic_id, :cursor_type, :cursor_value, :filters]

  field(:periodic_id, 1, type: :string)

  field(:cursor_type, 2, type: InternalApi.PeriodicScheduler.HistoryRequest.CursorType, enum: true)

  field(:cursor_value, 3, type: :uint64)
  field(:filters, 4, type: InternalApi.PeriodicScheduler.HistoryRequest.Filters)
end

defmodule InternalApi.PeriodicScheduler.HistoryRequest.Filters do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          branch_name: String.t(),
          pipeline_file: String.t(),
          triggered_by: String.t()
        }
  defstruct [:branch_name, :pipeline_file, :triggered_by]

  field(:branch_name, 1, type: :string)
  field(:pipeline_file, 2, type: :string)
  field(:triggered_by, 3, type: :string)
end

defmodule InternalApi.PeriodicScheduler.HistoryRequest.CursorType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:FIRST, 0)
  field(:AFTER, 1)
  field(:BEFORE, 2)
end

defmodule InternalApi.PeriodicScheduler.HistoryResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          triggers: [InternalApi.PeriodicScheduler.Trigger.t()],
          cursor_before: non_neg_integer,
          cursor_after: non_neg_integer
        }
  defstruct [:status, :triggers, :cursor_before, :cursor_after]

  field(:status, 1, type: InternalApi.Status)
  field(:triggers, 2, repeated: true, type: InternalApi.PeriodicScheduler.Trigger)
  field(:cursor_before, 3, type: :uint64)
  field(:cursor_after, 4, type: :uint64)
end

defmodule InternalApi.PeriodicScheduler.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          project_id: String.t(),
          requester_id: String.t(),
          page: integer,
          page_size: integer,
          order: integer,
          query: String.t()
        }
  defstruct [:organization_id, :project_id, :requester_id, :page, :page_size, :order, :query]

  field(:organization_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:requester_id, 3, type: :string)
  field(:page, 4, type: :int32)
  field(:page_size, 5, type: :int32)
  field(:order, 6, type: InternalApi.PeriodicScheduler.ListOrder, enum: true)
  field(:query, 7, type: :string)
end

defmodule InternalApi.PeriodicScheduler.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          periodics: [InternalApi.PeriodicScheduler.Periodic.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:status, :periodics, :page_number, :page_size, :total_entries, :total_pages]

  field(:status, 1, type: InternalApi.Status)
  field(:periodics, 2, repeated: true, type: InternalApi.PeriodicScheduler.Periodic)
  field(:page_number, 3, type: :int32)
  field(:page_size, 4, type: :int32)
  field(:total_entries, 5, type: :int32)
  field(:total_pages, 6, type: :int32)
end

defmodule InternalApi.PeriodicScheduler.ListKeysetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          project_id: String.t(),
          page_token: String.t(),
          page_size: integer,
          direction: integer,
          order: integer,
          query: String.t()
        }
  defstruct [:organization_id, :project_id, :page_token, :page_size, :direction, :order, :query]

  field(:organization_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:page_token, 3, type: :string)
  field(:page_size, 4, type: :int32)

  field(:direction, 5, type: InternalApi.PeriodicScheduler.ListKeysetRequest.Direction, enum: true)

  field(:order, 6, type: InternalApi.PeriodicScheduler.ListOrder, enum: true)
  field(:query, 7, type: :string)
end

defmodule InternalApi.PeriodicScheduler.ListKeysetRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NEXT, 0)
  field(:PREV, 1)
end

defmodule InternalApi.PeriodicScheduler.ListKeysetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          periodics: [InternalApi.PeriodicScheduler.Periodic.t()],
          next_page_token: String.t(),
          prev_page_token: String.t(),
          page_size: integer
        }
  defstruct [:status, :periodics, :next_page_token, :prev_page_token, :page_size]

  field(:status, 1, type: InternalApi.Status)
  field(:periodics, 2, repeated: true, type: InternalApi.PeriodicScheduler.Periodic)
  field(:next_page_token, 3, type: :string)
  field(:prev_page_token, 4, type: :string)
  field(:page_size, 5, type: :int32)
end

defmodule InternalApi.PeriodicScheduler.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          requester: String.t()
        }
  defstruct [:id, :requester]

  field(:id, 1, type: :string)
  field(:requester, 4, type: :string)
end

defmodule InternalApi.PeriodicScheduler.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t()
        }
  defstruct [:status]

  field(:status, 1, type: InternalApi.Status)
end

defmodule InternalApi.PeriodicScheduler.GetProjectIdRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          periodic_id: String.t(),
          project_name: String.t(),
          organization_id: String.t()
        }
  defstruct [:periodic_id, :project_name, :organization_id]

  field(:periodic_id, 1, type: :string)
  field(:project_name, 2, type: :string)
  field(:organization_id, 3, type: :string)
end

defmodule InternalApi.PeriodicScheduler.GetProjectIdResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          project_id: String.t()
        }
  defstruct [:status, :project_id]

  field(:status, 1, type: InternalApi.Status)
  field(:project_id, 2, type: :string)
end

defmodule InternalApi.PeriodicScheduler.VersionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.PeriodicScheduler.VersionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          version: String.t()
        }
  defstruct [:version]

  field(:version, 1, type: :string)
end

defmodule InternalApi.PeriodicScheduler.ListOrder do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BY_NAME_ASC, 0)
  field(:BY_CREATION_DATE_DESC, 1)
end

defmodule InternalApi.PeriodicScheduler.PeriodicService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.PeriodicScheduler.PeriodicService"

  rpc(
    :Apply,
    InternalApi.PeriodicScheduler.ApplyRequest,
    InternalApi.PeriodicScheduler.ApplyResponse
  )

  rpc(
    :Persist,
    InternalApi.PeriodicScheduler.PersistRequest,
    InternalApi.PeriodicScheduler.PersistResponse
  )

  rpc(
    :Pause,
    InternalApi.PeriodicScheduler.PauseRequest,
    InternalApi.PeriodicScheduler.PauseResponse
  )

  rpc(
    :Unpause,
    InternalApi.PeriodicScheduler.UnpauseRequest,
    InternalApi.PeriodicScheduler.UnpauseResponse
  )

  rpc(
    :RunNow,
    InternalApi.PeriodicScheduler.RunNowRequest,
    InternalApi.PeriodicScheduler.RunNowResponse
  )

  rpc(
    :Describe,
    InternalApi.PeriodicScheduler.DescribeRequest,
    InternalApi.PeriodicScheduler.DescribeResponse
  )

  rpc(
    :LatestTriggers,
    InternalApi.PeriodicScheduler.LatestTriggersRequest,
    InternalApi.PeriodicScheduler.LatestTriggersResponse
  )

  rpc(
    :History,
    InternalApi.PeriodicScheduler.HistoryRequest,
    InternalApi.PeriodicScheduler.HistoryResponse
  )

  rpc(
    :List,
    InternalApi.PeriodicScheduler.ListRequest,
    InternalApi.PeriodicScheduler.ListResponse
  )

  rpc(
    :ListKeyset,
    InternalApi.PeriodicScheduler.ListKeysetRequest,
    InternalApi.PeriodicScheduler.ListKeysetResponse
  )

  rpc(
    :Delete,
    InternalApi.PeriodicScheduler.DeleteRequest,
    InternalApi.PeriodicScheduler.DeleteResponse
  )

  rpc(
    :GetProjectId,
    InternalApi.PeriodicScheduler.GetProjectIdRequest,
    InternalApi.PeriodicScheduler.GetProjectIdResponse
  )

  rpc(
    :Version,
    InternalApi.PeriodicScheduler.VersionRequest,
    InternalApi.PeriodicScheduler.VersionResponse
  )
end

defmodule InternalApi.PeriodicScheduler.PeriodicService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.PeriodicScheduler.PeriodicService.Service
end
