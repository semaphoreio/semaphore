defmodule InternalApi.Usage.ListDailyUsageRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          period_started_at: Google.Protobuf.Timestamp.t(),
          period_finished_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :period_started_at, :period_finished_at]

  field :org_id, 1, type: :string
  field :period_started_at, 2, type: Google.Protobuf.Timestamp
  field :period_finished_at, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.ListDailyUsageResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          daily_usages: [InternalApi.Usage.DailyUsage.t()]
        }
  defstruct [:status, :daily_usages]

  field :status, 1, type: Google.Rpc.Status
  field :daily_usages, 2, repeated: true, type: InternalApi.Usage.DailyUsage
end

defmodule InternalApi.Usage.DailyUsage do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          resource_usages: [InternalApi.Usage.DailyResourceUsage.t()],
          date: Google.Protobuf.Timestamp.t()
        }
  defstruct [:resource_usages, :date]

  field :resource_usages, 1, repeated: true, type: InternalApi.Usage.DailyResourceUsage
  field :date, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.DailyResourceUsage do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine_type: String.t(),
          minutes_used: integer,
          seconds_used: integer
        }
  defstruct [:machine_type, :minutes_used, :seconds_used]

  field :machine_type, 1, type: :string
  field :minutes_used, 2, type: :int32
  field :seconds_used, 3, type: :int32
end

defmodule InternalApi.Usage.ProjectsUsageRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          period_started_at: Google.Protobuf.Timestamp.t(),
          period_finished_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :period_started_at, :period_finished_at]

  field :org_id, 1, type: :string
  field :period_started_at, 2, type: Google.Protobuf.Timestamp
  field :period_finished_at, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.ProjectsUsageResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          project_usages: [InternalApi.Usage.ProjectUsage.t()]
        }
  defstruct [:status, :project_usages]

  field :status, 1, type: Google.Rpc.Status
  field :project_usages, 2, repeated: true, type: InternalApi.Usage.ProjectUsage
end

defmodule InternalApi.Usage.ProjectUsage do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          resource_usages: [InternalApi.Usage.ResourceUsage.t()]
        }
  defstruct [:project_id, :resource_usages]

  field :project_id, 1, type: :string
  field :resource_usages, 2, repeated: true, type: InternalApi.Usage.ResourceUsage
end

defmodule InternalApi.Usage.TotalUsageRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          period_started_at: Google.Protobuf.Timestamp.t(),
          period_finished_at: Google.Protobuf.Timestamp.t(),
          org_id: String.t()
        }
  defstruct [:period_started_at, :period_finished_at, :org_id]

  field :period_started_at, 1, type: Google.Protobuf.Timestamp
  field :period_finished_at, 2, type: Google.Protobuf.Timestamp
  field :org_id, 3, type: :string
end

defmodule InternalApi.Usage.TotalUsageResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          resource_usages: [InternalApi.Usage.ResourceUsage.t()]
        }
  defstruct [:status, :resource_usages]

  field :status, 1, type: Google.Rpc.Status
  field :resource_usages, 2, repeated: true, type: InternalApi.Usage.ResourceUsage
end

defmodule InternalApi.Usage.TotalMembersUsageRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          period_started_at: Google.Protobuf.Timestamp.t(),
          period_finished_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :period_started_at, :period_finished_at]

  field :org_id, 1, type: :string
  field :period_started_at, 3, type: Google.Protobuf.Timestamp
  field :period_finished_at, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.TotalMembersUsageResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          members: integer,
          requesters: integer
        }
  defstruct [:members, :requesters]

  field :members, 1, type: :int32
  field :requesters, 2, type: :int32
end

defmodule InternalApi.Usage.ResourceUsage do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine_type: String.t(),
          seconds_used: integer
        }
  defstruct [:machine_type, :seconds_used]

  field :machine_type, 1, type: :string
  field :seconds_used, 2, type: :int32
end

defmodule InternalApi.Usage.ListQuotaUsageRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          points: integer,
          period_started_at: Google.Protobuf.Timestamp.t(),
          period_finished_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :points, :period_started_at, :period_finished_at]

  field :org_id, 1, type: :string
  field :points, 2, type: :int32
  field :period_started_at, 3, type: Google.Protobuf.Timestamp
  field :period_finished_at, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.ListQuotaUsageResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          usages: [InternalApi.Usage.QuotaUsage.t()]
        }
  defstruct [:status, :usages]

  field :status, 1, type: Google.Rpc.Status
  field :usages, 2, repeated: true, type: InternalApi.Usage.QuotaUsage
end

defmodule InternalApi.Usage.QuotaUsage do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          machine_type: String.t(),
          points: [InternalApi.Usage.QuotaUsage.Point.t()]
        }
  defstruct [:machine_type, :points]

  field :machine_type, 1, type: :string
  field :points, 2, repeated: true, type: InternalApi.Usage.QuotaUsage.Point
end

defmodule InternalApi.Usage.QuotaUsage.Point do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          usage: integer,
          date: Google.Protobuf.Timestamp.t()
        }
  defstruct [:usage, :date]

  field :usage, 1, type: :int32
  field :date, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.ListSeatsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          from_gte: Google.Protobuf.Timestamp.t(),
          to_lt: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :from_gte, :to_lt]

  field :org_id, 1, type: :string
  field :from_gte, 2, type: Google.Protobuf.Timestamp
  field :to_lt, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.ListSeatsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          seats: [InternalApi.Usage.Seat.t()]
        }
  defstruct [:seats]

  field :seats, 1, repeated: true, type: InternalApi.Usage.Seat
end

defmodule InternalApi.Usage.Seat do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          display_name: String.t(),
          origin: integer,
          status: integer,
          date: Google.Protobuf.Timestamp.t()
        }
  defstruct [:user_id, :display_name, :origin, :status, :date]

  field :user_id, 1, type: :string
  field :display_name, 2, type: :string
  field :origin, 3, type: InternalApi.Usage.SeatOrigin, enum: true
  field :status, 4, type: InternalApi.Usage.SeatStatus, enum: true
  field :date, 5, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.OrganizationPolicyApply do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          cutoff_date: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :cutoff_date]

  field :org_id, 1, type: :string
  field :cutoff_date, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Usage.SeatOrigin do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :SEAT_ORIGIN_UNSPECIFIED, 0
  field :SEAT_ORIGIN_SEMAPHORE, 1
  field :SEAT_ORIGIN_GITHUB, 2
  field :SEAT_ORIGIN_BITBUCKET, 3
  field :SEAT_ORIGIN_GITLAB, 4
end

defmodule InternalApi.Usage.SeatStatus do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :SEAT_TYPE_UNSPECIFIED, 0
  field :SEAT_TYPE_ACTIVE_MEMBER, 1
  field :SEAT_TYPE_NON_ACTIVE_MEMBER, 2
  field :SEAT_TYPE_NON_MEMBER, 3
end

defmodule InternalApi.Usage.UsageService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Usage.UsageService"

  rpc :ListDailyUsage,
      InternalApi.Usage.ListDailyUsageRequest,
      InternalApi.Usage.ListDailyUsageResponse

  rpc :ProjectsUsage,
      InternalApi.Usage.ProjectsUsageRequest,
      InternalApi.Usage.ProjectsUsageResponse

  rpc :TotalUsage, InternalApi.Usage.TotalUsageRequest, InternalApi.Usage.TotalUsageResponse

  rpc :ListQuotaUsage,
      InternalApi.Usage.ListQuotaUsageRequest,
      InternalApi.Usage.ListQuotaUsageResponse

  rpc :TotalMembersUsage,
      InternalApi.Usage.TotalMembersUsageRequest,
      InternalApi.Usage.TotalMembersUsageResponse

  rpc :ListSeats, InternalApi.Usage.ListSeatsRequest, InternalApi.Usage.ListSeatsResponse
end

defmodule InternalApi.Usage.UsageService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Usage.UsageService.Service
end
