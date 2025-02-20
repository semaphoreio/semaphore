defmodule InternalApi.Dashboardhub.RequestMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          api_version: String.t(),
          kind: String.t(),
          req_id: String.t(),
          org_id: String.t(),
          user_id: String.t()
        }
  defstruct [:api_version, :kind, :req_id, :org_id, :user_id]

  field(:api_version, 1, type: :string)
  field(:kind, 2, type: :string)
  field(:req_id, 3, type: :string)
  field(:org_id, 4, type: :string)
  field(:user_id, 5, type: :string)
end

defmodule InternalApi.Dashboardhub.Dashboard do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Dashboardhub.Dashboard.Metadata.t(),
          spec: InternalApi.Dashboardhub.Dashboard.Spec.t()
        }
  defstruct [:metadata, :spec]

  field(:metadata, 1, type: InternalApi.Dashboardhub.Dashboard.Metadata)
  field(:spec, 2, type: InternalApi.Dashboardhub.Dashboard.Spec)
end

defmodule InternalApi.Dashboardhub.Dashboard.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          title: String.t(),
          create_time: integer,
          update_time: integer,
          org_id: String.t()
        }
  defstruct [:name, :id, :title, :create_time, :update_time, :org_id]

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:title, 3, type: :string)
  field(:create_time, 4, type: :int64)
  field(:update_time, 5, type: :int64)
  field(:org_id, 6, type: :string)
end

defmodule InternalApi.Dashboardhub.Dashboard.Spec do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          widgets: [InternalApi.Dashboardhub.Dashboard.Spec.Widget.t()]
        }
  defstruct [:widgets]

  field(:widgets, 2, repeated: true, type: InternalApi.Dashboardhub.Dashboard.Spec.Widget)
end

defmodule InternalApi.Dashboardhub.Dashboard.Spec.Widget do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          filters: %{String.t() => String.t()}
        }
  defstruct [:name, :type, :filters]

  field(:name, 1, type: :string)
  field(:type, 2, type: :string)

  field(:filters, 3,
    repeated: true,
    type: InternalApi.Dashboardhub.Dashboard.Spec.Widget.FiltersEntry,
    map: true
  )
end

defmodule InternalApi.Dashboardhub.Dashboard.Spec.Widget.FiltersEntry do
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

defmodule InternalApi.Dashboardhub.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Dashboardhub.RequestMeta.t(),
          page_size: integer,
          page_token: String.t()
        }
  defstruct [:metadata, :page_size, :page_token]

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
end

defmodule InternalApi.Dashboardhub.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboards: [InternalApi.Dashboardhub.Dashboard.t()],
          next_page_token: String.t(),
          page_size: integer
        }
  defstruct [:dashboards, :next_page_token, :page_size]

  field(:dashboards, 1, repeated: true, type: InternalApi.Dashboardhub.Dashboard)
  field(:next_page_token, 2, type: :string)
  field(:page_size, 3, type: :int32)
end

defmodule InternalApi.Dashboardhub.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Dashboardhub.RequestMeta.t(),
          dashboard: InternalApi.Dashboardhub.Dashboard.t()
        }
  defstruct [:metadata, :dashboard]

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:dashboard, 2, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboard: InternalApi.Dashboardhub.Dashboard.t()
        }
  defstruct [:dashboard]

  field(:dashboard, 1, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Dashboardhub.RequestMeta.t(),
          id_or_name: String.t()
        }
  defstruct [:metadata, :id_or_name]

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:id_or_name, 2, type: :string)
end

defmodule InternalApi.Dashboardhub.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboard: InternalApi.Dashboardhub.Dashboard.t()
        }
  defstruct [:dashboard]

  field(:dashboard, 1, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Dashboardhub.RequestMeta.t(),
          id_or_name: String.t(),
          dashboard: InternalApi.Dashboardhub.Dashboard.t()
        }
  defstruct [:metadata, :id_or_name, :dashboard]

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:id_or_name, 2, type: :string)
  field(:dashboard, 3, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboard: InternalApi.Dashboardhub.Dashboard.t()
        }
  defstruct [:dashboard]

  field(:dashboard, 1, type: InternalApi.Dashboardhub.Dashboard)
end

defmodule InternalApi.Dashboardhub.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Dashboardhub.RequestMeta.t(),
          id_or_name: String.t()
        }
  defstruct [:metadata, :id_or_name]

  field(:metadata, 1, type: InternalApi.Dashboardhub.RequestMeta)
  field(:id_or_name, 2, type: :string)
end

defmodule InternalApi.Dashboardhub.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }
  defstruct [:id]

  field(:id, 1, type: :string)
end

defmodule InternalApi.Dashboardhub.DashboardEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboard_id: String.t(),
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:dashboard_id, :org_id, :timestamp]

  field(:dashboard_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Dashboardhub.DashboardsService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Dashboardhub.DashboardsService"

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
