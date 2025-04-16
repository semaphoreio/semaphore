defmodule InternalApi.Delivery.Canvas do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          organization_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          stages: [InternalApi.Delivery.Stage.t()],
          event_sources: [InternalApi.Delivery.EventSource.t()]
        }
  defstruct [:id, :name, :organization_id, :created_at, :stages, :event_sources]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:organization_id, 3, type: :string)
  field(:created_at, 4, type: Google.Protobuf.Timestamp)
  field(:stages, 5, repeated: true, type: InternalApi.Delivery.Stage)
  field(:event_sources, 6, repeated: true, type: InternalApi.Delivery.EventSource)
end

defmodule InternalApi.Delivery.CreateCanvasRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          organization_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:name, :organization_id, :requester_id]

  field(:name, 1, type: :string)
  field(:organization_id, 2, type: :string)
  field(:requester_id, 3, type: :string)
end

defmodule InternalApi.Delivery.CreateCanvasResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          canvas: InternalApi.Delivery.Canvas.t()
        }
  defstruct [:canvas]

  field(:canvas, 1, type: InternalApi.Delivery.Canvas)
end

defmodule InternalApi.Delivery.DescribeCanvasRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          organization_id: String.t()
        }
  defstruct [:id, :organization_id]

  field(:id, 1, type: :string)
  field(:organization_id, 2, type: :string)
end

defmodule InternalApi.Delivery.DescribeCanvasResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          canvas: InternalApi.Delivery.Canvas.t()
        }
  defstruct [:canvas]

  field(:canvas, 1, type: InternalApi.Delivery.Canvas)
end

defmodule InternalApi.Delivery.EventSource do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          organization_id: String.t(),
          canvas_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:id, :name, :organization_id, :canvas_id, :created_at]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:organization_id, 3, type: :string)
  field(:canvas_id, 4, type: :string)
  field(:created_at, 5, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Delivery.CreateEventSourceRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          organization_id: String.t(),
          canvas_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:name, :organization_id, :canvas_id, :requester_id]

  field(:name, 1, type: :string)
  field(:organization_id, 2, type: :string)
  field(:canvas_id, 3, type: :string)
  field(:requester_id, 4, type: :string)
end

defmodule InternalApi.Delivery.CreateEventSourceResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          event_source: InternalApi.Delivery.EventSource.t(),
          key: String.t()
        }
  defstruct [:event_source, :key]

  field(:event_source, 1, type: InternalApi.Delivery.EventSource)
  field(:key, 2, type: :string)
end

defmodule InternalApi.Delivery.DescribeEventSourceRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          organization_id: String.t(),
          canvas_id: String.t()
        }
  defstruct [:id, :organization_id, :canvas_id]

  field(:id, 1, type: :string)
  field(:organization_id, 2, type: :string)
  field(:canvas_id, 3, type: :string)
end

defmodule InternalApi.Delivery.DescribeEventSourceResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          event_source: InternalApi.Delivery.EventSource.t()
        }
  defstruct [:event_source]

  field(:event_source, 1, type: InternalApi.Delivery.EventSource)
end

defmodule InternalApi.Delivery.Connection do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          name: String.t(),
          filters: [InternalApi.Delivery.Connection.Filter.t()],
          filter_operator: integer
        }
  defstruct [:type, :name, :filters, :filter_operator]

  field(:type, 1, type: InternalApi.Delivery.Connection.Type, enum: true)
  field(:name, 2, type: :string)
  field(:filters, 3, repeated: true, type: InternalApi.Delivery.Connection.Filter)
  field(:filter_operator, 4, type: InternalApi.Delivery.Connection.FilterOperator, enum: true)
end

defmodule InternalApi.Delivery.Connection.Filter do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          expression: InternalApi.Delivery.Connection.ExpressionFilter.t()
        }
  defstruct [:type, :expression]

  field(:type, 1, type: InternalApi.Delivery.Connection.FilterType, enum: true)
  field(:expression, 2, type: InternalApi.Delivery.Connection.ExpressionFilter)
end

defmodule InternalApi.Delivery.Connection.ExpressionFilter do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          expression: String.t(),
          variables: [InternalApi.Delivery.Connection.ExpressionFilter.Variable.t()]
        }
  defstruct [:expression, :variables]

  field(:expression, 1, type: :string)

  field(:variables, 2,
    repeated: true,
    type: InternalApi.Delivery.Connection.ExpressionFilter.Variable
  )
end

defmodule InternalApi.Delivery.Connection.ExpressionFilter.Variable do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          path: String.t()
        }
  defstruct [:name, :path]

  field(:name, 1, type: :string)
  field(:path, 2, type: :string)
end

defmodule InternalApi.Delivery.Connection.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:TYPE_UNKNOWN, 0)
  field(:TYPE_EVENT_SOURCE, 1)
  field(:TYPE_STAGE, 2)
end

defmodule InternalApi.Delivery.Connection.FilterType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:FILTER_TYPE_UNKNOWN, 0)
  field(:FILTER_TYPE_EXPRESSION, 1)
end

defmodule InternalApi.Delivery.Connection.FilterOperator do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:FILTER_OPERATOR_AND, 0)
  field(:FILTER_OPERATOR_OR, 1)
end

defmodule InternalApi.Delivery.Stage do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          organization_id: String.t(),
          canvas_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          connections: [InternalApi.Delivery.Connection.t()],
          approval_required: boolean,
          run_template: InternalApi.Delivery.RunTemplate.t()
        }
  defstruct [
    :id,
    :name,
    :organization_id,
    :canvas_id,
    :created_at,
    :connections,
    :approval_required,
    :run_template
  ]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:organization_id, 3, type: :string)
  field(:canvas_id, 4, type: :string)
  field(:created_at, 5, type: Google.Protobuf.Timestamp)
  field(:connections, 6, repeated: true, type: InternalApi.Delivery.Connection)
  field(:approval_required, 7, type: :bool)
  field(:run_template, 8, type: InternalApi.Delivery.RunTemplate)
end

defmodule InternalApi.Delivery.CreateStageRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          organization_id: String.t(),
          canvas_id: String.t(),
          connections: [InternalApi.Delivery.Connection.t()],
          approval_required: boolean,
          requester_id: String.t(),
          run_template: InternalApi.Delivery.RunTemplate.t()
        }
  defstruct [
    :name,
    :organization_id,
    :canvas_id,
    :connections,
    :approval_required,
    :requester_id,
    :run_template
  ]

  field(:name, 1, type: :string)
  field(:organization_id, 2, type: :string)
  field(:canvas_id, 3, type: :string)
  field(:connections, 4, repeated: true, type: InternalApi.Delivery.Connection)
  field(:approval_required, 5, type: :bool)
  field(:requester_id, 6, type: :string)
  field(:run_template, 7, type: InternalApi.Delivery.RunTemplate)
end

defmodule InternalApi.Delivery.RunTemplate do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          semaphore_workflow: InternalApi.Delivery.WorkflowTemplate.t(),
          semaphore_task: InternalApi.Delivery.TaskTemplate.t()
        }
  defstruct [:type, :semaphore_workflow, :semaphore_task]

  field(:type, 1, type: InternalApi.Delivery.RunTemplate.Type, enum: true)
  field(:semaphore_workflow, 2, type: InternalApi.Delivery.WorkflowTemplate)
  field(:semaphore_task, 3, type: InternalApi.Delivery.TaskTemplate)
end

defmodule InternalApi.Delivery.RunTemplate.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:TYPE_UNKNOWN, 0)
  field(:TYPE_SEMAPHORE_WORKFLOW, 1)
  field(:TYPE_SEMAPHORE_TASK, 2)
end

defmodule InternalApi.Delivery.WorkflowTemplate do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          branch: String.t(),
          pipeline_file: String.t()
        }
  defstruct [:project_id, :branch, :pipeline_file]

  field(:project_id, 1, type: :string)
  field(:branch, 2, type: :string)
  field(:pipeline_file, 3, type: :string)
end

defmodule InternalApi.Delivery.TaskTemplate do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          task_id: String.t(),
          branch: String.t(),
          pipeline_file: String.t(),
          parameters: %{String.t() => String.t()}
        }
  defstruct [:project_id, :task_id, :branch, :pipeline_file, :parameters]

  field(:project_id, 1, type: :string)
  field(:task_id, 2, type: :string)
  field(:branch, 3, type: :string)
  field(:pipeline_file, 4, type: :string)

  field(:parameters, 5,
    repeated: true,
    type: InternalApi.Delivery.TaskTemplate.ParametersEntry,
    map: true
  )
end

defmodule InternalApi.Delivery.TaskTemplate.ParametersEntry do
  @moduledoc false
  use Protobuf, map: true, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }
  defstruct [:key, :value]

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.Delivery.CreateStageResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stage: InternalApi.Delivery.Stage.t()
        }
  defstruct [:stage]

  field(:stage, 1, type: InternalApi.Delivery.Stage)
end

defmodule InternalApi.Delivery.UpdateStageRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          connections: [InternalApi.Delivery.Connection.t()],
          requester_id: String.t()
        }
  defstruct [:id, :connections, :requester_id]

  field(:id, 1, type: :string)
  field(:connections, 2, repeated: true, type: InternalApi.Delivery.Connection)
  field(:requester_id, 3, type: :string)
end

defmodule InternalApi.Delivery.UpdateStageResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stage: InternalApi.Delivery.Stage.t()
        }
  defstruct [:stage]

  field(:stage, 1, type: InternalApi.Delivery.Stage)
end

defmodule InternalApi.Delivery.ListStageEventsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stage_id: String.t(),
          states: [integer]
        }
  defstruct [:stage_id, :states]

  field(:stage_id, 1, type: :string)
  field(:states, 2, repeated: true, type: InternalApi.Delivery.StageEvent.State, enum: true)
end

defmodule InternalApi.Delivery.ListStageEventsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          events: [InternalApi.Delivery.StageEvent.t()]
        }
  defstruct [:events]

  field(:events, 1, repeated: true, type: InternalApi.Delivery.StageEvent)
end

defmodule InternalApi.Delivery.StageEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          source_id: String.t(),
          source_type: integer,
          state: integer,
          created_at: Google.Protobuf.Timestamp.t(),
          approved_at: Google.Protobuf.Timestamp.t(),
          approved_by: String.t()
        }
  defstruct [:id, :source_id, :source_type, :state, :created_at, :approved_at, :approved_by]

  field(:id, 1, type: :string)
  field(:source_id, 2, type: :string)
  field(:source_type, 3, type: InternalApi.Delivery.Connection.Type, enum: true)
  field(:state, 4, type: InternalApi.Delivery.StageEvent.State, enum: true)
  field(:created_at, 5, type: Google.Protobuf.Timestamp)
  field(:approved_at, 6, type: Google.Protobuf.Timestamp)
  field(:approved_by, 7, type: :string)
end

defmodule InternalApi.Delivery.StageEvent.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:UNKNOWN, 0)
  field(:PENDING, 1)
  field(:WAITING_FOR_APPROVAL, 2)
  field(:WAITING_FOR_TIME_WINDOW, 3)
  field(:PROCESSED, 4)
end

defmodule InternalApi.Delivery.ApproveStageEventRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stage_id: String.t(),
          event_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:stage_id, :event_id, :requester_id]

  field(:stage_id, 1, type: :string)
  field(:event_id, 2, type: :string)
  field(:requester_id, 3, type: :string)
end

defmodule InternalApi.Delivery.ApproveStageEventResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Delivery.Delivery.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Delivery.Delivery"

  rpc(
    :CreateCanvas,
    InternalApi.Delivery.CreateCanvasRequest,
    InternalApi.Delivery.CreateCanvasResponse
  )

  rpc(
    :DescribeCanvas,
    InternalApi.Delivery.DescribeCanvasRequest,
    InternalApi.Delivery.DescribeCanvasResponse
  )

  rpc(
    :CreateEventSource,
    InternalApi.Delivery.CreateEventSourceRequest,
    InternalApi.Delivery.CreateEventSourceResponse
  )

  rpc(
    :CreateStage,
    InternalApi.Delivery.CreateStageRequest,
    InternalApi.Delivery.CreateStageResponse
  )

  rpc(
    :UpdateStage,
    InternalApi.Delivery.UpdateStageRequest,
    InternalApi.Delivery.UpdateStageResponse
  )

  rpc(
    :ListStageEvents,
    InternalApi.Delivery.ListStageEventsRequest,
    InternalApi.Delivery.ListStageEventsResponse
  )

  rpc(
    :ApproveStageEvent,
    InternalApi.Delivery.ApproveStageEventRequest,
    InternalApi.Delivery.ApproveStageEventResponse
  )
end

defmodule InternalApi.Delivery.Delivery.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Delivery.Delivery.Service
end
