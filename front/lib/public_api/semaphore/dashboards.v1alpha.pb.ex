defmodule Semaphore.Dashboards.V1alpha.Dashboard do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: Semaphore.Dashboards.V1alpha.Dashboard.Metadata.t(),
          spec: Semaphore.Dashboards.V1alpha.Dashboard.Spec.t()
        }
  defstruct [:metadata, :spec]

  field(:metadata, 1, type: Semaphore.Dashboards.V1alpha.Dashboard.Metadata)
  field(:spec, 2, type: Semaphore.Dashboards.V1alpha.Dashboard.Spec)
end

defmodule Semaphore.Dashboards.V1alpha.Dashboard.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          title: String.t(),
          create_time: integer,
          update_time: integer
        }
  defstruct [:name, :id, :title, :create_time, :update_time]

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:title, 3, type: :string)
  field(:create_time, 4, type: :int64)
  field(:update_time, 5, type: :int64)
end

defmodule Semaphore.Dashboards.V1alpha.Dashboard.Spec do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          widgets: [Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget.t()]
        }
  defstruct [:widgets]

  field(:widgets, 2, repeated: true, type: Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget)
end

defmodule Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget do
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
    type: Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget.FiltersEntry,
    map: true
  )
end

defmodule Semaphore.Dashboards.V1alpha.Dashboard.Spec.Widget.FiltersEntry do
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

defmodule Semaphore.Dashboards.V1alpha.ListDashboardsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t()
        }
  defstruct [:page_size, :page_token]

  field(:page_size, 1, type: :int32)
  field(:page_token, 2, type: :string)
end

defmodule Semaphore.Dashboards.V1alpha.ListDashboardsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboards: [Semaphore.Dashboards.V1alpha.Dashboard.t()],
          next_page_token: String.t(),
          total_size: integer
        }
  defstruct [:dashboards, :next_page_token, :total_size]

  field(:dashboards, 1, repeated: true, type: Semaphore.Dashboards.V1alpha.Dashboard)
  field(:next_page_token, 2, type: :string)
  field(:total_size, 3, type: :int32)
end

defmodule Semaphore.Dashboards.V1alpha.GetDashboardRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id_or_name: String.t()
        }
  defstruct [:id_or_name]

  field(:id_or_name, 1, type: :string)
end

defmodule Semaphore.Dashboards.V1alpha.UpdateDashboardRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id_or_name: String.t(),
          dashboard: Semaphore.Dashboards.V1alpha.Dashboard.t()
        }
  defstruct [:id_or_name, :dashboard]

  field(:id_or_name, 1, type: :string)
  field(:dashboard, 2, type: Semaphore.Dashboards.V1alpha.Dashboard)
end

defmodule Semaphore.Dashboards.V1alpha.DeleteDashboardRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id_or_name: String.t()
        }
  defstruct [:id_or_name]

  field(:id_or_name, 1, type: :string)
end

defmodule Semaphore.Dashboards.V1alpha.Empty do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule Semaphore.Dashboards.V1alpha.DashboardsApi.Service do
  @moduledoc false
  use GRPC.Service, name: "semaphore.dashboards.v1alpha.DashboardsApi"

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
