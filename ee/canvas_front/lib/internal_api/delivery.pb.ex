defmodule InternalApi.Delivery.Connection.Type do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :TYPE_UNKNOWN, 0
  field :TYPE_EVENT_SOURCE, 1
  field :TYPE_STAGE, 2
end

defmodule InternalApi.Delivery.Connection.FilterType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :FILTER_TYPE_UNKNOWN, 0
  field :FILTER_TYPE_DATA, 1
end

defmodule InternalApi.Delivery.Connection.FilterOperator do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :FILTER_OPERATOR_AND, 0
  field :FILTER_OPERATOR_OR, 1
end

defmodule InternalApi.Delivery.RunTemplate.Type do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :TYPE_UNKNOWN, 0
  field :TYPE_SEMAPHORE, 1
end

defmodule InternalApi.Delivery.StageEvent.State do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :UNKNOWN, 0
  field :PENDING, 1
  field :WAITING_FOR_APPROVAL, 2
  field :WAITING_FOR_TIME_WINDOW, 3
  field :PROCESSED, 4
end

defmodule InternalApi.Delivery.Canvas do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :organization_id, 3, type: :string, json_name: "organizationId"
  field :created_by, 4, type: :string, json_name: "createdBy"
  field :created_at, 5, type: Google.Protobuf.Timestamp, json_name: "createdAt"
end

defmodule InternalApi.Delivery.CreateCanvasRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
  field :organization_id, 2, type: :string, json_name: "organizationId"
  field :requester_id, 3, type: :string, json_name: "requesterId"
end

defmodule InternalApi.Delivery.CreateCanvasResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas, 1, type: InternalApi.Delivery.Canvas
end

defmodule InternalApi.Delivery.DescribeCanvasRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :organization_id, 3, type: :string, json_name: "organizationId"
end

defmodule InternalApi.Delivery.DescribeCanvasResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas, 1, type: InternalApi.Delivery.Canvas
end

defmodule InternalApi.Delivery.EventSource do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :organization_id, 3, type: :string, json_name: "organizationId"
  field :canvas_id, 4, type: :string, json_name: "canvasId"
  field :created_at, 5, type: Google.Protobuf.Timestamp, json_name: "createdAt"
end

defmodule InternalApi.Delivery.DescribeStageRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :organization_id, 3, type: :string, json_name: "organizationId"
  field :canvas_id, 4, type: :string, json_name: "canvasId"
end

defmodule InternalApi.Delivery.DescribeStageResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :stage, 1, type: InternalApi.Delivery.Stage
end

defmodule InternalApi.Delivery.CreateEventSourceRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
  field :organization_id, 2, type: :string, json_name: "organizationId"
  field :canvas_id, 3, type: :string, json_name: "canvasId"
  field :requester_id, 4, type: :string, json_name: "requesterId"
end

defmodule InternalApi.Delivery.CreateEventSourceResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :event_source, 1, type: InternalApi.Delivery.EventSource, json_name: "eventSource"
  field :key, 2, type: :string
end

defmodule InternalApi.Delivery.DescribeEventSourceRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :organization_id, 3, type: :string, json_name: "organizationId"
  field :canvas_id, 4, type: :string, json_name: "canvasId"
end

defmodule InternalApi.Delivery.DescribeEventSourceResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :event_source, 1, type: InternalApi.Delivery.EventSource, json_name: "eventSource"
end

defmodule InternalApi.Delivery.Connection.Filter do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :type, 1, type: InternalApi.Delivery.Connection.FilterType, enum: true
  field :data, 2, type: InternalApi.Delivery.Connection.DataFilter
end

defmodule InternalApi.Delivery.Connection.DataFilter do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :expression, 1, type: :string
end

defmodule InternalApi.Delivery.Connection do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :type, 1, type: InternalApi.Delivery.Connection.Type, enum: true
  field :name, 2, type: :string
  field :filters, 3, repeated: true, type: InternalApi.Delivery.Connection.Filter

  field :filter_operator, 4,
    type: InternalApi.Delivery.Connection.FilterOperator,
    json_name: "filterOperator",
    enum: true
end

defmodule InternalApi.Delivery.Stage do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :organization_id, 3, type: :string, json_name: "organizationId"
  field :canvas_id, 4, type: :string, json_name: "canvasId"
  field :created_at, 5, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :connections, 6, repeated: true, type: InternalApi.Delivery.Connection
  field :approval_required, 7, type: :bool, json_name: "approvalRequired"
  field :run_template, 8, type: InternalApi.Delivery.RunTemplate, json_name: "runTemplate"
end

defmodule InternalApi.Delivery.CreateStageRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
  field :organization_id, 2, type: :string, json_name: "organizationId"
  field :canvas_id, 3, type: :string, json_name: "canvasId"
  field :connections, 4, repeated: true, type: InternalApi.Delivery.Connection
  field :approval_required, 5, type: :bool, json_name: "approvalRequired"
  field :requester_id, 6, type: :string, json_name: "requesterId"
  field :run_template, 7, type: InternalApi.Delivery.RunTemplate, json_name: "runTemplate"
end

defmodule InternalApi.Delivery.RunTemplate do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :type, 1, type: InternalApi.Delivery.RunTemplate.Type, enum: true
  field :semaphore, 2, type: InternalApi.Delivery.SemaphoreRunTemplate
end

defmodule InternalApi.Delivery.SemaphoreRunTemplate.ParametersEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule InternalApi.Delivery.SemaphoreRunTemplate do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :project_id, 1, type: :string, json_name: "projectId"
  field :branch, 2, type: :string
  field :pipeline_file, 3, type: :string, json_name: "pipelineFile"
  field :task_id, 4, type: :string, json_name: "taskId"

  field :parameters, 5,
    repeated: true,
    type: InternalApi.Delivery.SemaphoreRunTemplate.ParametersEntry,
    map: true
end

defmodule InternalApi.Delivery.CreateStageResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :stage, 1, type: InternalApi.Delivery.Stage
end

defmodule InternalApi.Delivery.UpdateStageRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
  field :connections, 2, repeated: true, type: InternalApi.Delivery.Connection
  field :requester_id, 3, type: :string, json_name: "requesterId"
end

defmodule InternalApi.Delivery.UpdateStageResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :stage, 1, type: InternalApi.Delivery.Stage
end

defmodule InternalApi.Delivery.ListStagesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :organization_id, 1, type: :string, json_name: "organizationId"
  field :canvas_id, 2, type: :string, json_name: "canvasId"
end

defmodule InternalApi.Delivery.ListStagesResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :stages, 1, repeated: true, type: InternalApi.Delivery.Stage
end

defmodule InternalApi.Delivery.ListEventSourcesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :organization_id, 1, type: :string, json_name: "organizationId"
  field :canvas_id, 2, type: :string, json_name: "canvasId"
end

defmodule InternalApi.Delivery.ListEventSourcesResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :event_sources, 1,
    repeated: true,
    type: InternalApi.Delivery.EventSource,
    json_name: "eventSources"
end

defmodule InternalApi.Delivery.ListStageEventsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :stage_id, 1, type: :string, json_name: "stageId"
  field :organization_id, 2, type: :string, json_name: "organizationId"
  field :canvas_id, 3, type: :string, json_name: "canvasId"
  field :states, 4, repeated: true, type: InternalApi.Delivery.StageEvent.State, enum: true
end

defmodule InternalApi.Delivery.ListStageEventsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :events, 1, repeated: true, type: InternalApi.Delivery.StageEvent
end

defmodule InternalApi.Delivery.StageEvent do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
  field :source_id, 2, type: :string, json_name: "sourceId"

  field :source_type, 3,
    type: InternalApi.Delivery.Connection.Type,
    json_name: "sourceType",
    enum: true

  field :state, 4, type: InternalApi.Delivery.StageEvent.State, enum: true
  field :created_at, 5, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :approved_at, 6, type: Google.Protobuf.Timestamp, json_name: "approvedAt"
  field :approved_by, 7, type: :string, json_name: "approvedBy"
end

defmodule InternalApi.Delivery.ApproveStageEventRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :stage_id, 1, type: :string, json_name: "stageId"
  field :organization_id, 2, type: :string, json_name: "organizationId"
  field :canvas_id, 3, type: :string, json_name: "canvasId"
  field :event_id, 4, type: :string, json_name: "eventId"
  field :requester_id, 5, type: :string, json_name: "requesterId"
end

defmodule InternalApi.Delivery.ApproveStageEventResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :event, 1, type: InternalApi.Delivery.StageEvent
end

defmodule InternalApi.Delivery.StageCreated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas_id, 1, type: :string, json_name: "canvasId"
  field :stage_id, 2, type: :string, json_name: "stageId"
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Delivery.EventSourceCreated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas_id, 1, type: :string, json_name: "canvasId"
  field :source_id, 2, type: :string, json_name: "sourceId"
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Delivery.StageEventCreated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas_id, 1, type: :string, json_name: "canvasId"
  field :stage_id, 2, type: :string, json_name: "stageId"
  field :event_id, 3, type: :string, json_name: "eventId"
  field :timestamp, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Delivery.StageEventApproved do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas_id, 1, type: :string, json_name: "canvasId"
  field :stage_id, 2, type: :string, json_name: "stageId"
  field :event_id, 3, type: :string, json_name: "eventId"
  field :timestamp, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Delivery.StageExecutionCreated do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas_id, 1, type: :string, json_name: "canvasId"
  field :execution_id, 2, type: :string, json_name: "executionId"
  field :stage_id, 3, type: :string, json_name: "stageId"
  field :event_id, 4, type: :string, json_name: "eventId"
  field :timestamp, 5, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Delivery.StageExecutionStarted do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas_id, 1, type: :string, json_name: "canvasId"
  field :execution_id, 2, type: :string, json_name: "executionId"
  field :stage_id, 3, type: :string, json_name: "stageId"
  field :event_id, 4, type: :string, json_name: "eventId"
  field :timestamp, 5, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Delivery.StageExecutionFinished do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :canvas_id, 1, type: :string, json_name: "canvasId"
  field :execution_id, 2, type: :string, json_name: "executionId"
  field :stage_id, 3, type: :string, json_name: "stageId"
  field :event_id, 4, type: :string, json_name: "eventId"
  field :timestamp, 5, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Delivery.Delivery.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Delivery.Delivery", protoc_gen_elixir_version: "0.14.1"

  rpc(
    :CreateCanvas,
    InternalApi.Delivery.CreateCanvasRequest,
    InternalApi.Delivery.CreateCanvasResponse
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
    :DescribeCanvas,
    InternalApi.Delivery.DescribeCanvasRequest,
    InternalApi.Delivery.DescribeCanvasResponse
  )

  rpc(
    :DescribeStage,
    InternalApi.Delivery.DescribeStageRequest,
    InternalApi.Delivery.DescribeStageResponse
  )

  rpc(
    :DescribeEventSource,
    InternalApi.Delivery.DescribeEventSourceRequest,
    InternalApi.Delivery.DescribeEventSourceResponse
  )

  rpc(
    :ListStages,
    InternalApi.Delivery.ListStagesRequest,
    InternalApi.Delivery.ListStagesResponse
  )

  rpc(
    :ListEventSources,
    InternalApi.Delivery.ListEventSourcesRequest,
    InternalApi.Delivery.ListEventSourcesResponse
  )

  rpc(
    :ListStageEvents,
    InternalApi.Delivery.ListStageEventsRequest,
    InternalApi.Delivery.ListStageEventsResponse
  )

  rpc(
    :UpdateStage,
    InternalApi.Delivery.UpdateStageRequest,
    InternalApi.Delivery.UpdateStageResponse
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
