defmodule InternalApi.Audit.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          all_events_in_operation: boolean
        }
  defstruct [:org_id, :all_events_in_operation]

  field(:org_id, 1, type: :string)
  field(:all_events_in_operation, 2, type: :bool)
end

defmodule InternalApi.Audit.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          events: [InternalApi.Audit.Event.t()]
        }
  defstruct [:events]

  field(:events, 1, repeated: true, type: InternalApi.Audit.Event)
end

defmodule InternalApi.Audit.PaginatedListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          page_size: integer,
          page_token: String.t(),
          direction: integer
        }
  defstruct [:org_id, :page_size, :page_token, :direction]

  field(:org_id, 1, type: :string)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
  field(:direction, 4, type: InternalApi.Audit.PaginatedListRequest.Direction, enum: true)
end

defmodule InternalApi.Audit.PaginatedListRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.Audit.PaginatedListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          events: [InternalApi.Audit.Event.t()],
          next_page_token: String.t(),
          previous_page_token: String.t()
        }
  defstruct [:events, :next_page_token, :previous_page_token]

  field(:events, 1, repeated: true, type: InternalApi.Audit.Event)
  field(:next_page_token, 2, type: :string)
  field(:previous_page_token, 3, type: :string)
end

defmodule InternalApi.Audit.ListStreamLogsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          page_size: integer,
          page_token: String.t(),
          direction: integer
        }
  defstruct [:org_id, :page_size, :page_token, :direction]

  field(:org_id, 1, type: :string)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
  field(:direction, 4, type: InternalApi.Audit.ListStreamLogsRequest.Direction, enum: true)
end

defmodule InternalApi.Audit.ListStreamLogsRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.Audit.ListStreamLogsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream_logs: [InternalApi.Audit.StreamLog.t()],
          next_page_token: String.t(),
          previous_page_token: String.t()
        }
  defstruct [:stream_logs, :next_page_token, :previous_page_token]

  field(:stream_logs, 1, repeated: true, type: InternalApi.Audit.StreamLog)
  field(:next_page_token, 2, type: :string)
  field(:previous_page_token, 3, type: :string)
end

defmodule InternalApi.Audit.StreamLog do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          timestamp: Google.Protobuf.Timestamp.t(),
          error_message: String.t(),
          file_size: integer,
          file_name: String.t(),
          first_event_timestamp: Google.Protobuf.Timestamp.t(),
          last_event_timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :timestamp,
    :error_message,
    :file_size,
    :file_name,
    :first_event_timestamp,
    :last_event_timestamp
  ]

  field(:timestamp, 1, type: Google.Protobuf.Timestamp)
  field(:error_message, 2, type: :string)
  field(:file_size, 3, type: :int32)
  field(:file_name, 4, type: :string)
  field(:first_event_timestamp, 5, type: Google.Protobuf.Timestamp)
  field(:last_event_timestamp, 6, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Audit.Stream do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          provider: integer,
          status: integer,
          s3_config: InternalApi.Audit.S3StreamConfig.t()
        }
  defstruct [:org_id, :provider, :status, :s3_config]

  field(:org_id, 1, type: :string)
  field(:provider, 2, type: InternalApi.Audit.StreamProvider, enum: true)
  field(:status, 3, type: InternalApi.Audit.StreamStatus, enum: true)
  field(:s3_config, 4, type: InternalApi.Audit.S3StreamConfig)
end

defmodule InternalApi.Audit.EditMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t(),
          activity_toggled_at: Google.Protobuf.Timestamp.t(),
          updated_by: String.t(),
          activity_toggled_by: String.t()
        }
  defstruct [:created_at, :updated_at, :activity_toggled_at, :updated_by, :activity_toggled_by]

  field(:created_at, 1, type: Google.Protobuf.Timestamp)
  field(:updated_at, 2, type: Google.Protobuf.Timestamp)
  field(:activity_toggled_at, 3, type: Google.Protobuf.Timestamp)
  field(:updated_by, 4, type: :string)
  field(:activity_toggled_by, 5, type: :string)
end

defmodule InternalApi.Audit.S3StreamConfig do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          bucket: String.t(),
          key_id: String.t(),
          key_secret: String.t(),
          host: String.t(),
          region: String.t(),
          type: integer
        }
  defstruct [:bucket, :key_id, :key_secret, :host, :region, :type]

  field(:bucket, 1, type: :string)
  field(:key_id, 2, type: :string)
  field(:key_secret, 3, type: :string)
  field(:host, 4, type: :string)
  field(:region, 5, type: :string)
  field(:type, 6, type: InternalApi.Audit.S3StreamConfig.Type, enum: true)
end

defmodule InternalApi.Audit.S3StreamConfig.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:USER, 0)
  field(:INSTANCE_ROLE, 1)
end

defmodule InternalApi.Audit.TestStreamRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream: InternalApi.Audit.Stream.t()
        }
  defstruct [:stream]

  field(:stream, 1, type: InternalApi.Audit.Stream)
end

defmodule InternalApi.Audit.TestStreamResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          success: boolean,
          message: String.t()
        }
  defstruct [:success, :message]

  field(:success, 1, type: :bool)
  field(:message, 2, type: :string)
end

defmodule InternalApi.Audit.CreateStreamRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream: InternalApi.Audit.Stream.t(),
          user_id: String.t()
        }
  defstruct [:stream, :user_id]

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.Audit.CreateStreamResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream: InternalApi.Audit.Stream.t(),
          meta: InternalApi.Audit.EditMeta.t()
        }
  defstruct [:stream, :meta]

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:meta, 2, type: InternalApi.Audit.EditMeta)
end

defmodule InternalApi.Audit.DescribeStreamRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Audit.DescribeStreamResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream: InternalApi.Audit.Stream.t(),
          meta: InternalApi.Audit.EditMeta.t()
        }
  defstruct [:stream, :meta]

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:meta, 2, type: InternalApi.Audit.EditMeta)
end

defmodule InternalApi.Audit.UpdateStreamRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream: InternalApi.Audit.Stream.t(),
          user_id: String.t()
        }
  defstruct [:stream, :user_id]

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.Audit.UpdateStreamResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream: InternalApi.Audit.Stream.t(),
          meta: InternalApi.Audit.EditMeta.t()
        }
  defstruct [:stream, :meta]

  field(:stream, 1, type: InternalApi.Audit.Stream)
  field(:meta, 2, type: InternalApi.Audit.EditMeta)
end

defmodule InternalApi.Audit.DestroyStreamRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Audit.SetStreamStateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          status: integer,
          user_id: String.t()
        }
  defstruct [:org_id, :status, :user_id]

  field(:org_id, 1, type: :string)
  field(:status, 2, type: InternalApi.Audit.StreamStatus, enum: true)
  field(:user_id, 3, type: :string)
end

defmodule InternalApi.Audit.Event do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          resource: integer,
          operation: integer,
          user_id: String.t(),
          org_id: String.t(),
          ip_address: String.t(),
          username: String.t(),
          description: String.t(),
          metadata: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          operation_id: String.t(),
          resource_id: String.t(),
          resource_name: String.t(),
          medium: integer
        }
  defstruct [
    :resource,
    :operation,
    :user_id,
    :org_id,
    :ip_address,
    :username,
    :description,
    :metadata,
    :timestamp,
    :operation_id,
    :resource_id,
    :resource_name,
    :medium
  ]

  field(:resource, 1, type: InternalApi.Audit.Event.Resource, enum: true)
  field(:operation, 2, type: InternalApi.Audit.Event.Operation, enum: true)
  field(:user_id, 3, type: :string)
  field(:org_id, 4, type: :string)
  field(:ip_address, 5, type: :string)
  field(:username, 6, type: :string)
  field(:description, 7, type: :string)
  field(:metadata, 8, type: :string)
  field(:timestamp, 9, type: Google.Protobuf.Timestamp)
  field(:operation_id, 10, type: :string)
  field(:resource_id, 11, type: :string)
  field(:resource_name, 12, type: :string)
  field(:medium, 13, type: InternalApi.Audit.Event.Medium, enum: true)
end

defmodule InternalApi.Audit.Event.Resource do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

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
  field(:ServiceAccount, 20)
end

defmodule InternalApi.Audit.Event.Operation do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

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
  use Protobuf, enum: true, syntax: :proto3

  field(:Web, 0)
  field(:API, 1)
  field(:CLI, 2)
end

defmodule InternalApi.Audit.StreamProvider do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:S3, 0)
end

defmodule InternalApi.Audit.StreamStatus do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ACTIVE, 0)
  field(:PAUSED, 1)
end

defmodule InternalApi.Audit.AuditService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Audit.AuditService"

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
