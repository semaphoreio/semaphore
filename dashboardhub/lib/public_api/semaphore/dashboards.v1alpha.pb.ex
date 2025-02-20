defmodule Semaphore.Dashboards.V1alpha.Dashboard.Metadata do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:title, 3, type: :string)
  field(:create_time, 4, type: :int64, json_name: "createTime")
  field(:update_time, 5, type: :int64, json_name: "updateTime")
end

defmodule Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget.FiltersEntry do
  @moduledoc false

  use Protobuf, map: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:type, 2, type: :string)

  field(:filters, 3,
    repeated: true,
    type: Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget.FiltersEntry,
    map: true
  )
end

defmodule Semaphore.Dashboards.V1alpha.Dashboard.Spec do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:widgets, 2, repeated: true, type: Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget)
end

defmodule Semaphore.Dashboards.V1alpha.Dashboard do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: Semaphore.Dashboards.V1alpha.Dashboard.Metadata)
  field(:spec, 2, type: Semaphore.Dashboards.V1alpha.Dashboard.Spec)
end

defmodule Semaphore.Dashboards.V1alpha.ListDashboardsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:page_size, 1, type: :int32, json_name: "pageSize")
  field(:page_token, 2, type: :string, json_name: "pageToken")
end

defmodule Semaphore.Dashboards.V1alpha.ListDashboardsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:dashboards, 1, repeated: true, type: Semaphore.Dashboards.V1alpha.Dashboard)
  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
  field(:total_size, 3, type: :int32, json_name: "totalSize")
end

defmodule Semaphore.Dashboards.V1alpha.GetDashboardRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id_or_name, 1, type: :string, json_name: "idOrName")
end

defmodule Semaphore.Dashboards.V1alpha.UpdateDashboardRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id_or_name, 1, type: :string, json_name: "idOrName")
  field(:dashboard, 2, type: Semaphore.Dashboards.V1alpha.Dashboard)
end

defmodule Semaphore.Dashboards.V1alpha.DeleteDashboardRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id_or_name, 1, type: :string, json_name: "idOrName")
end

defmodule Semaphore.Dashboards.V1alpha.Empty do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule Semaphore.Dashboards.V1alpha.DashboardsApi.Service do
  @moduledoc false

  use GRPC.Service,
    name: "semaphore.dashboards.v1alpha.DashboardsApi",
    protoc_gen_elixir_version: "0.12.0"

  rpc(
    :ListDashboards,
    Semaphore.Dashboards.V1alpha.ListDashboardsRequest,
    Semaphore.Dashboards.V1alpha.ListDashboardsResponse
  )

  rpc(
    :GetDashboard,
    Semaphore.Dashboards.V1alpha.GetDashboardRequest,
    Semaphore.Dashboards.V1alpha.Dashboard
  )

  rpc(
    :CreateDashboard,
    Semaphore.Dashboards.V1alpha.Dashboard,
    Semaphore.Dashboards.V1alpha.Dashboard
  )

  rpc(
    :UpdateDashboard,
    Semaphore.Dashboards.V1alpha.UpdateDashboardRequest,
    Semaphore.Dashboards.V1alpha.Dashboard
  )

  rpc(
    :DeleteDashboard,
    Semaphore.Dashboards.V1alpha.DeleteDashboardRequest,
    Semaphore.Dashboards.V1alpha.Empty
  )
end

defmodule Semaphore.Dashboards.V1alpha.DashboardsApi.Stub do
  @moduledoc false

  use GRPC.Stub, service: Semaphore.Dashboards.V1alpha.DashboardsApi.Service
end
