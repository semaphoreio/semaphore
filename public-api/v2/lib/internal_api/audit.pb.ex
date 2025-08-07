defmodule InternalApi.Audit.StreamProvider do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:S3, 0)
end

defmodule InternalApi.Audit.StreamStatus do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:ACTIVE, 0)
  field(:PAUSED, 1)
end

defmodule InternalApi.Audit.PaginatedListRequest.Direction do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.Audit.ListStreamLogsRequest.Direction do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.Audit.S3StreamConfig.Type do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:USER, 0)
  field(:INSTANCE_ROLE, 1)
end

defmodule InternalApi.Audit.Event.Resource do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:Project, 0)
  field(:User, 1)
  field(:Workflow, 2)
  field(:Pipeline, 3)
  field(:DebugSession, 4)
  field(:PeriodicScheduler, 5)
  field(:Secret, 6)
  field(:Notification, 7)
  field(:Dashboard, 8)
  field(:Job, 9)
  field(:Artifact, 10)
  field(:Organization, 11)
  field(:SelfHostedAgentType, 12)
  field(:SelfHostedAgent, 13)
  field(:CustomDashboard, 14)
  field(:CustomDashboardItem, 15)
  field(:ProjectInsightsSettings, 16)
  field(:Okta, 17)
  field(:FlakyTests, 18)
  field(:RBACRole, 19)
end

defmodule InternalApi.Audit.Event.Operation do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:Added, 0)
  field(:Removed, 1)
  field(:Modified, 2)
  field(:Started, 3)
  field(:Stopped, 4)
  field(:Promoted, 5)
  field(:Demoted, 6)
  field(:Rebuild, 7)
  field(:Download, 8)
  field(:Disabled, 9)
end

defmodule InternalApi.Audit.Event.Medium do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:Web, 0)
  field(:API, 1)
  field(:CLI, 2)
end

defmodule InternalApi.Audit.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:all_events_in_operation, 2, type: :bool, json_name: "allEventsInOperation")
end

defmodule InternalApi.Audit.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:events, 1, repeated: true, type: InternalApi.Audit.Event)
end

defmodule InternalApi.Audit.PaginatedListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:page_token, 3, type: :string, json_name: "pageToken")
  field(:direction, 4, type: InternalApi.Audit.PaginatedListRequest.Direction, enum: true)
end

defmodule InternalApi.Audit.PaginatedListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:events, 1, repeated: true, type: InternalApi.Audit.Event)
  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
  field(:previous_page_token, 3, type: :string, json_name: "previousPageToken")
end

defmodule InternalApi.Audit.ListStreamLogsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:page_token, 3, type: :string, json_name: "pageToken")
  field(:direction, 4, type: InternalApi.Audit.ListStreamLogsRequest.Direction, enum: true)
end

defmodule InternalApi.Audit.ListStreamLogsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:stream_logs, 1,
    repeated: true,
    type: InternalApi.Audit.StreamLog,
    json_name: "streamLogs"
  )

  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
  field(:previous_page_token, 3, type: :string, json_name: "previousPageToken")
end

defmodule InternalApi.Audit.StreamLog do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:timestamp, 1, type: Google.Protobuf.Timestamp)
  field(:error_message, 2, type: :string, json_name: "errorMessage")
  field(:file_size, 3, type: :int32, json_name: "fileSize")
  field(:file_name, 4, type: :string, json_name: "fileName")

  field(:first_event_timestamp, 5,
    type: Google.Protobuf.Timestamp,
    json_name: "firstEventTimestamp"
  )

  field(:last_event_timestamp, 6,
    type: Google.Protobuf.Timestamp,
    json_name: "lastEventTimestamp"
  )
end

defmodule InternalApi.Audit.Stream do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:provider, 2, type: InternalApi.Audit.StreamProvider, enum: true)
  field(:status, 3, type: InternalApi.Audit.StreamStatus, enum: true)
  field(:s3_config, 4, type: InternalApi.Audit.S3StreamConfig, json_name: "s3Config")
end

defmodule InternalApi.Audit.EditMeta do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:created_at, 1, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 2, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
  field(:activity_toggled_at, 3, type: Google.Protobuf.Timestamp, json_name: "activityToggledAt")
  field(:updated_by, 4, type: :string, json_name: "updatedBy")
  field(:activity_toggled_by, 5, type: :string, json_name: "activityToggledBy")
end

defmodule InternalApi.Audit.S3StreamConfig do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:bucket, 1, type: :string)
  field(:key_id, 2, type: :string, json_name: "keyId")
  field(:key_secret, 3, type: :string, json_name: "keySecret")
  field(:host, 4, type: :string)
  field(:region, 5, type: :string)
  field(:type, 6, type: InternalApi.Audit.S3StreamConfig.Type, enum: true)
end

defmodule InternalApi.Audit.TestStreamRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:stream, 1, type: InternalApi.Audit.Stream)
end

defmodule InternalApi.Audit.TestStreamResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:success, 1, type: :bool)
  field(:message, 2, type: :string)
end

defmodule InternalApi.Audit.CreateStreamRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:user_id, 2, type: :string, json_name: "userId")
end

defmodule InternalApi.Audit.CreateStreamResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:meta, 2, type: InternalApi.Audit.EditMeta)
end

defmodule InternalApi.Audit.DescribeStreamRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Audit.DescribeStreamResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:meta, 2, type: InternalApi.Audit.EditMeta)
end

defmodule InternalApi.Audit.UpdateStreamRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:user_id, 2, type: :string, json_name: "userId")
end

defmodule InternalApi.Audit.UpdateStreamResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:meta, 2, type: InternalApi.Audit.EditMeta)
end

defmodule InternalApi.Audit.DestroyStreamRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Audit.SetStreamStateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:status, 2, type: InternalApi.Audit.StreamStatus, enum: true)
  field(:user_id, 3, type: :string, json_name: "userId")
end

defmodule InternalApi.Audit.Event do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:resource, 1, type: InternalApi.Audit.Event.Resource, enum: true)
  field(:operation, 2, type: InternalApi.Audit.Event.Operation, enum: true)
  field(:user_id, 3, type: :string, json_name: "userId")
  field(:org_id, 4, type: :string, json_name: "orgId")
  field(:ip_address, 5, type: :string, json_name: "ipAddress")
  field(:username, 6, type: :string)
  field(:description, 7, type: :string)
  field(:metadata, 8, type: :string)
  field(:timestamp, 9, type: Google.Protobuf.Timestamp)
  field(:operation_id, 10, type: :string, json_name: "operationId")
  field(:resource_id, 11, type: :string, json_name: "resourceId")
  field(:resource_name, 12, type: :string, json_name: "resourceName")
  field(:medium, 13, type: InternalApi.Audit.Event.Medium, enum: true)
end

defmodule InternalApi.Audit.AuditService.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Audit.AuditService", protoc_gen_elixir_version: "0.12.0"

  rpc(:List, InternalApi.Audit.ListRequest, InternalApi.Audit.ListResponse)

  rpc(
    :PaginatedList,
    InternalApi.Audit.PaginatedListRequest,
    InternalApi.Audit.PaginatedListResponse
  )

  rpc(:TestStream, InternalApi.Audit.TestStreamRequest, InternalApi.Audit.TestStreamResponse)

  rpc(
    :CreateStream,
    InternalApi.Audit.CreateStreamRequest,
    InternalApi.Audit.CreateStreamResponse
  )

  rpc(
    :DescribeStream,
    InternalApi.Audit.DescribeStreamRequest,
    InternalApi.Audit.DescribeStreamResponse
  )

  rpc(
    :UpdateStream,
    InternalApi.Audit.UpdateStreamRequest,
    InternalApi.Audit.UpdateStreamResponse
  )

  rpc(:DestroyStream, InternalApi.Audit.DestroyStreamRequest, Google.Protobuf.Empty)

  rpc(:SetStreamState, InternalApi.Audit.SetStreamStateRequest, Google.Protobuf.Empty)

  rpc(
    :ListStreamLogs,
    InternalApi.Audit.ListStreamLogsRequest,
    InternalApi.Audit.ListStreamLogsResponse
  )
end

defmodule InternalApi.Audit.AuditService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Audit.AuditService.Service
end
