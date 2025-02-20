defmodule InternalApi.PeriodicScheduler.ListOrder do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BY_NAME_ASC, 0)
  field(:BY_CREATION_DATE_DESC, 1)
end

defmodule InternalApi.PeriodicScheduler.PersistRequest.ScheduleState do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:UNCHANGED, 0)
  field(:ACTIVE, 1)
  field(:PAUSED, 2)
end

defmodule InternalApi.PeriodicScheduler.HistoryRequest.CursorType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:FIRST, 0)
  field(:AFTER, 1)
  field(:BEFORE, 2)
end

defmodule InternalApi.PeriodicScheduler.ListKeysetRequest.Direction do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:NEXT, 0)
  field(:PREV, 1)
end

defmodule InternalApi.PeriodicScheduler.ApplyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:requester_id, 1, type: :string, json_name: "requesterId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
  field(:yml_definition, 3, type: :string, json_name: "ymlDefinition")
end

defmodule InternalApi.PeriodicScheduler.ApplyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:id, 2, type: :string)
end

defmodule InternalApi.PeriodicScheduler.PersistRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:recurring, 4, type: :bool)
  field(:state, 5, type: InternalApi.PeriodicScheduler.PersistRequest.ScheduleState, enum: true)
  field(:organization_id, 6, type: :string, json_name: "organizationId")
  field(:project_name, 7, type: :string, json_name: "projectName")
  field(:requester_id, 8, type: :string, json_name: "requesterId")
  field(:branch, 9, type: :string)
  field(:pipeline_file, 10, type: :string, json_name: "pipelineFile")
  field(:at, 11, type: :string)
  field(:parameters, 12, repeated: true, type: InternalApi.PeriodicScheduler.Periodic.Parameter)
  field(:project_id, 13, type: :string, json_name: "projectId")
end

defmodule InternalApi.PeriodicScheduler.PersistResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:periodic, 2, type: InternalApi.PeriodicScheduler.Periodic)
end

defmodule InternalApi.PeriodicScheduler.PauseRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
  field(:requester, 2, type: :string)
end

defmodule InternalApi.PeriodicScheduler.PauseResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
end

defmodule InternalApi.PeriodicScheduler.UnpauseRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
  field(:requester, 2, type: :string)
end

defmodule InternalApi.PeriodicScheduler.UnpauseResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
end

defmodule InternalApi.PeriodicScheduler.RunNowRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
  field(:requester, 2, type: :string)
  field(:branch, 3, type: :string)
  field(:pipeline_file, 4, type: :string, json_name: "pipelineFile")

  field(:parameter_values, 5,
    repeated: true,
    type: InternalApi.PeriodicScheduler.ParameterValue,
    json_name: "parameterValues"
  )
end

defmodule InternalApi.PeriodicScheduler.RunNowResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:periodic, 2, type: InternalApi.PeriodicScheduler.Periodic)
  field(:triggers, 3, repeated: true, type: InternalApi.PeriodicScheduler.Trigger)
  field(:trigger, 4, type: InternalApi.PeriodicScheduler.Trigger)
end

defmodule InternalApi.PeriodicScheduler.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
end

defmodule InternalApi.PeriodicScheduler.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:periodic, 2, type: InternalApi.PeriodicScheduler.Periodic)
  field(:triggers, 3, repeated: true, type: InternalApi.PeriodicScheduler.Trigger)
end

defmodule InternalApi.PeriodicScheduler.Periodic.Parameter do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:required, 2, type: :bool)
  field(:description, 3, type: :string)
  field(:default_value, 4, type: :string, json_name: "defaultValue")
  field(:options, 5, repeated: true, type: :string)
end

defmodule InternalApi.PeriodicScheduler.Periodic do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:project_id, 3, type: :string, json_name: "projectId")
  field(:branch, 4, type: :string)
  field(:at, 5, type: :string)
  field(:pipeline_file, 6, type: :string, json_name: "pipelineFile")
  field(:requester_id, 7, type: :string, json_name: "requesterId")
  field(:updated_at, 8, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
  field(:suspended, 9, type: :bool)
  field(:paused, 10, type: :bool)
  field(:pause_toggled_by, 11, type: :string, json_name: "pauseToggledBy")
  field(:pause_toggled_at, 12, type: Google.Protobuf.Timestamp, json_name: "pauseToggledAt")
  field(:inserted_at, 13, type: Google.Protobuf.Timestamp, json_name: "insertedAt")
  field(:recurring, 14, type: :bool)
  field(:parameters, 15, repeated: true, type: InternalApi.PeriodicScheduler.Periodic.Parameter)
  field(:description, 16, type: :string)
  field(:organization_id, 17, type: :string, json_name: "organizationId")
end

defmodule InternalApi.PeriodicScheduler.Trigger do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:triggered_at, 1, type: Google.Protobuf.Timestamp, json_name: "triggeredAt")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:branch, 3, type: :string)
  field(:pipeline_file, 4, type: :string, json_name: "pipelineFile")
  field(:scheduling_status, 5, type: :string, json_name: "schedulingStatus")
  field(:scheduled_workflow_id, 6, type: :string, json_name: "scheduledWorkflowId")
  field(:scheduled_at, 7, type: Google.Protobuf.Timestamp, json_name: "scheduledAt")
  field(:error_description, 8, type: :string, json_name: "errorDescription")
  field(:run_now_requester_id, 9, type: :string, json_name: "runNowRequesterId")
  field(:periodic_id, 10, type: :string, json_name: "periodicId")

  field(:parameter_values, 11,
    repeated: true,
    type: InternalApi.PeriodicScheduler.ParameterValue,
    json_name: "parameterValues"
  )
end

defmodule InternalApi.PeriodicScheduler.ParameterValue do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.PeriodicScheduler.LatestTriggersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:periodic_ids, 1, repeated: true, type: :string, json_name: "periodicIds")
end

defmodule InternalApi.PeriodicScheduler.LatestTriggersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:triggers, 2, repeated: true, type: InternalApi.PeriodicScheduler.Trigger)
end

defmodule InternalApi.PeriodicScheduler.HistoryRequest.Filters do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:branch_name, 1, type: :string, json_name: "branchName")
  field(:pipeline_file, 2, type: :string, json_name: "pipelineFile")
  field(:triggered_by, 3, type: :string, json_name: "triggeredBy")
end

defmodule InternalApi.PeriodicScheduler.HistoryRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:periodic_id, 1, type: :string, json_name: "periodicId")

  field(:cursor_type, 2,
    type: InternalApi.PeriodicScheduler.HistoryRequest.CursorType,
    json_name: "cursorType",
    enum: true
  )

  field(:cursor_value, 3, type: :uint64, json_name: "cursorValue")
  field(:filters, 4, type: InternalApi.PeriodicScheduler.HistoryRequest.Filters)
end

defmodule InternalApi.PeriodicScheduler.HistoryResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:triggers, 2, repeated: true, type: InternalApi.PeriodicScheduler.Trigger)
  field(:cursor_before, 3, type: :uint64, json_name: "cursorBefore")
  field(:cursor_after, 4, type: :uint64, json_name: "cursorAfter")
end

defmodule InternalApi.PeriodicScheduler.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:requester_id, 3, type: :string, json_name: "requesterId")
  field(:page, 4, type: :int32)
  field(:page_size, 5, type: :int32, json_name: "pageSize")
  field(:order, 6, type: InternalApi.PeriodicScheduler.ListOrder, enum: true)
  field(:query, 7, type: :string)
end

defmodule InternalApi.PeriodicScheduler.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:periodics, 2, repeated: true, type: InternalApi.PeriodicScheduler.Periodic)
  field(:page_number, 3, type: :int32, json_name: "pageNumber")
  field(:page_size, 4, type: :int32, json_name: "pageSize")
  field(:total_entries, 5, type: :int32, json_name: "totalEntries")
  field(:total_pages, 6, type: :int32, json_name: "totalPages")
end

defmodule InternalApi.PeriodicScheduler.ListKeysetRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:page_token, 3, type: :string, json_name: "pageToken")
  field(:page_size, 4, type: :int32, json_name: "pageSize")

  field(:direction, 5,
    type: InternalApi.PeriodicScheduler.ListKeysetRequest.Direction,
    enum: true
  )

  field(:order, 6, type: InternalApi.PeriodicScheduler.ListOrder, enum: true)
  field(:query, 7, type: :string)
end

defmodule InternalApi.PeriodicScheduler.ListKeysetResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:periodics, 2, repeated: true, type: InternalApi.PeriodicScheduler.Periodic)
  field(:next_page_token, 3, type: :string, json_name: "nextPageToken")
  field(:prev_page_token, 4, type: :string, json_name: "prevPageToken")
  field(:page_size, 5, type: :int32, json_name: "pageSize")
end

defmodule InternalApi.PeriodicScheduler.DeleteRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
  field(:requester, 4, type: :string)
end

defmodule InternalApi.PeriodicScheduler.DeleteResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
end

defmodule InternalApi.PeriodicScheduler.GetProjectIdRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:periodic_id, 1, type: :string, json_name: "periodicId")
  field(:project_name, 2, type: :string, json_name: "projectName")
  field(:organization_id, 3, type: :string, json_name: "organizationId")
end

defmodule InternalApi.PeriodicScheduler.GetProjectIdResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:project_id, 2, type: :string, json_name: "projectId")
end

defmodule InternalApi.PeriodicScheduler.VersionRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.PeriodicScheduler.VersionResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:version, 1, type: :string)
end

defmodule InternalApi.PeriodicScheduler.PeriodicService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.PeriodicScheduler.PeriodicService",
    protoc_gen_elixir_version: "0.12.0"

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
