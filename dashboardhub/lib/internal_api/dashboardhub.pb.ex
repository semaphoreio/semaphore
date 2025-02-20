defmodule InternalApi.Dashboardhub.RequestMeta do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:api_version, 1, type: :string, json_name: "apiVersion")
  field(:kind, 2, type: :string)
  field(:req_id, 3, type: :string, json_name: "reqId")
  field(:org_id, 4, type: :string, json_name: "orgId")
  field(:user_id, 5, type: :string, json_name: "userId")
end

defmodule InternalApi.Dashboardhub.Dashboard.Metadata do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:title, 3, type: :string)
  field(:create_time, 4, type: :int64, json_name: "createTime")
  field(:update_time, 5, type: :int64, json_name: "updateTime")
  field(:org_id, 6, type: :string, json_name: "orgId")
end

defmodule InternalApi.Dashboardhub.Dashboard.Spec.Widget.FiltersEntry do
  @moduledoc false

  use Protobuf, map: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:key, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.Dashboardhub.Dashboard.Spec.Widget do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:type, 2, type: :string)

  field(:filters, 3,
    repeated: true,
    type: InternalApi.Dashboardhub.Dashboard.Spec.Widget.FiltersEntry,
    map: true
  )
end

defmodule InternalApi.Dashboardhub.Dashboard.Spec do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:widgets, 2, repeated: true, type: InternalApi.Dashboardhub.Dashboard.Spec.Widget)
end

defmodule InternalApi.Dashboardhub.Dashboard do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Dashboardhub.Dashboard.Metadata)
  field(:spec, 2, type: InternalApi.Dashboardhub.Dashboard.Spec)
end

defmodule InternalApi.Dashboardhub.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:page_token, 3, type: :string, json_name: "pageToken")
end

defmodule InternalApi.Dashboardhub.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:dashboards, 1, repeated: true, type: InternalApi.Dashboardhub.Dashboard)
  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
  field(:page_size, 3, type: :int32, json_name: "pageSize")
end

defmodule InternalApi.Dashboardhub.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:dashboard, 2, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:dashboard, 1, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:id_or_name, 2, type: :string, json_name: "idOrName")
end

defmodule InternalApi.Dashboardhub.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:dashboard, 1, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.UpdateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:id_or_name, 2, type: :string, json_name: "idOrName")
  field(:dashboard, 3, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.UpdateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:dashboard, 1, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.DestroyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:id_or_name, 2, type: :string, json_name: "idOrName")
end

defmodule InternalApi.Dashboardhub.DestroyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:id, 1, type: :string)
end

defmodule InternalApi.Dashboardhub.DashboardEvent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:dashboard_id, 1, type: :string, json_name: "dashboardId")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Dashboardhub.DashboardsService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Dashboardhub.DashboardsService",
    protoc_gen_elixir_version: "0.12.0"

  rpc(:List, InternalApi.Dashboardhub.ListRequest, InternalApi.Dashboardhub.ListResponse)

  rpc(
    :Describe,
    InternalApi.Dashboardhub.DescribeRequest,
    InternalApi.Dashboardhub.DescribeResponse
  )

  rpc(:Create, InternalApi.Dashboardhub.CreateRequest, InternalApi.Dashboardhub.CreateResponse)

  rpc(:Update, InternalApi.Dashboardhub.UpdateRequest, InternalApi.Dashboardhub.UpdateResponse)

  rpc(:Destroy, InternalApi.Dashboardhub.DestroyRequest, InternalApi.Dashboardhub.DestroyResponse)
end

defmodule InternalApi.Dashboardhub.DashboardsService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Dashboardhub.DashboardsService.Service
end
