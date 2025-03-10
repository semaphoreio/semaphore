defmodule InternalApi.Usage.SeatOrigin do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:SEAT_ORIGIN_UNSPECIFIED, 0)
  field(:SEAT_ORIGIN_SEMAPHORE, 1)
  field(:SEAT_ORIGIN_GITHUB, 2)
  field(:SEAT_ORIGIN_BITBUCKET, 3)
end

defmodule InternalApi.Usage.SeatStatus do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:SEAT_TYPE_UNSPECIFIED, 0)
  field(:SEAT_TYPE_ACTIVE_MEMBER, 1)
  field(:SEAT_TYPE_NON_ACTIVE_MEMBER, 2)
  field(:SEAT_TYPE_NON_MEMBER, 3)
end

defmodule InternalApi.Usage.ListDailyUsageRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:period_started_at, 2, type: Google.Protobuf.Timestamp, json_name: "periodStartedAt")
  field(:period_finished_at, 3, type: Google.Protobuf.Timestamp, json_name: "periodFinishedAt")
end

defmodule InternalApi.Usage.ListDailyUsageResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: Google.Rpc.Status)

  field(:daily_usages, 2,
    repeated: true,
    type: InternalApi.Usage.DailyUsage,
    json_name: "dailyUsages"
  )
end

defmodule InternalApi.Usage.DailyUsage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:resource_usages, 1,
    repeated: true,
    type: InternalApi.Usage.DailyResourceUsage,
    json_name: "resourceUsages"
  )

  field(:date, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Usage.DailyResourceUsage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:machine_type, 1, type: :string, json_name: "machineType")
  field(:minutes_used, 2, type: :int32, json_name: "minutesUsed")
  field(:seconds_used, 3, type: :int32, json_name: "secondsUsed")
end

defmodule InternalApi.Usage.ProjectsUsageRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:period_started_at, 2, type: Google.Protobuf.Timestamp, json_name: "periodStartedAt")
  field(:period_finished_at, 3, type: Google.Protobuf.Timestamp, json_name: "periodFinishedAt")
end

defmodule InternalApi.Usage.ProjectsUsageResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: Google.Rpc.Status)

  field(:project_usages, 2,
    repeated: true,
    type: InternalApi.Usage.ProjectUsage,
    json_name: "projectUsages"
  )
end

defmodule InternalApi.Usage.ProjectUsage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")

  field(:resource_usages, 2,
    repeated: true,
    type: InternalApi.Usage.ResourceUsage,
    json_name: "resourceUsages"
  )
end

defmodule InternalApi.Usage.TotalUsageRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:period_started_at, 1, type: Google.Protobuf.Timestamp, json_name: "periodStartedAt")
  field(:period_finished_at, 2, type: Google.Protobuf.Timestamp, json_name: "periodFinishedAt")
  field(:org_id, 3, type: :string, json_name: "orgId")
end

defmodule InternalApi.Usage.TotalUsageResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: Google.Rpc.Status)

  field(:resource_usages, 2,
    repeated: true,
    type: InternalApi.Usage.ResourceUsage,
    json_name: "resourceUsages"
  )
end

defmodule InternalApi.Usage.TotalMembersUsageRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:period_started_at, 3, type: Google.Protobuf.Timestamp, json_name: "periodStartedAt")
  field(:period_finished_at, 4, type: Google.Protobuf.Timestamp, json_name: "periodFinishedAt")
end

defmodule InternalApi.Usage.TotalMembersUsageResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:members, 1, type: :int32)
  field(:requesters, 2, type: :int32)
end

defmodule InternalApi.Usage.ResourceUsage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:machine_type, 1, type: :string, json_name: "machineType")
  field(:seconds_used, 2, type: :int32, json_name: "secondsUsed")
end

defmodule InternalApi.Usage.ListQuotaUsageRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:points, 2, type: :int32)
  field(:period_started_at, 3, type: Google.Protobuf.Timestamp, json_name: "periodStartedAt")
  field(:period_finished_at, 4, type: Google.Protobuf.Timestamp, json_name: "periodFinishedAt")
end

defmodule InternalApi.Usage.ListQuotaUsageResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: Google.Rpc.Status)
  field(:usages, 2, repeated: true, type: InternalApi.Usage.QuotaUsage)
end

defmodule InternalApi.Usage.QuotaUsage.Point do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:usage, 1, type: :int32)
  field(:date, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Usage.QuotaUsage do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:machine_type, 1, type: :string, json_name: "machineType")
  field(:points, 2, repeated: true, type: InternalApi.Usage.QuotaUsage.Point)
end

defmodule InternalApi.Usage.ListSeatsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:from_gte, 2, type: Google.Protobuf.Timestamp, json_name: "fromGte")
  field(:to_lt, 3, type: Google.Protobuf.Timestamp, json_name: "toLt")
end

defmodule InternalApi.Usage.ListSeatsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:seats, 1, repeated: true, type: InternalApi.Usage.Seat)
end

defmodule InternalApi.Usage.Seat do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:display_name, 2, type: :string, json_name: "displayName")
  field(:origin, 3, type: InternalApi.Usage.SeatOrigin, enum: true)
  field(:status, 4, type: InternalApi.Usage.SeatStatus, enum: true)
  field(:date, 5, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Usage.UsageService.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Usage.UsageService", protoc_gen_elixir_version: "0.13.0"

  rpc(
    :ListDailyUsage,
    InternalApi.Usage.ListDailyUsageRequest,
    InternalApi.Usage.ListDailyUsageResponse
  )

  rpc(
    :ProjectsUsage,
    InternalApi.Usage.ProjectsUsageRequest,
    InternalApi.Usage.ProjectsUsageResponse
  )

  rpc(:TotalUsage, InternalApi.Usage.TotalUsageRequest, InternalApi.Usage.TotalUsageResponse)

  rpc(
    :ListQuotaUsage,
    InternalApi.Usage.ListQuotaUsageRequest,
    InternalApi.Usage.ListQuotaUsageResponse
  )

  rpc(
    :TotalMembersUsage,
    InternalApi.Usage.TotalMembersUsageRequest,
    InternalApi.Usage.TotalMembersUsageResponse
  )

  rpc(:ListSeats, InternalApi.Usage.ListSeatsRequest, InternalApi.Usage.ListSeatsResponse)
end

defmodule InternalApi.Usage.UsageService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Usage.UsageService.Service
end
