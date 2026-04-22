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
