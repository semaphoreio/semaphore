defmodule InternalApi.PermissionPatrol.HasPermissionsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t(),
          project_id: String.t(),
          permissions: [String.t()]
        }
  defstruct [:user_id, :org_id, :project_id, :permissions]

  field(:user_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:project_id, 3, type: :string)
  field(:permissions, 4, repeated: true, type: :string)
end

defmodule InternalApi.PermissionPatrol.HasPermissionsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          has_permissions: %{String.t() => boolean}
        }
  defstruct [:has_permissions]

  field(:has_permissions, 1,
    repeated: true,
    type: InternalApi.PermissionPatrol.HasPermissionsResponse.HasPermissionsEntry,
    map: true
  )
end

defmodule InternalApi.PermissionPatrol.HasPermissionsResponse.HasPermissionsEntry do
  @moduledoc false
  use Protobuf, map: true, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: boolean
        }
  defstruct [:key, :value]

  field(:key, 1, type: :string)
  field(:value, 2, type: :bool)
end

defmodule InternalApi.PermissionPatrol.PermissionPatrol.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.PermissionPatrol.PermissionPatrol"

  rpc(
    :HasPermissions,
    InternalApi.PermissionPatrol.HasPermissionsRequest,
    InternalApi.PermissionPatrol.HasPermissionsResponse
  )
end

defmodule InternalApi.PermissionPatrol.PermissionPatrol.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.PermissionPatrol.PermissionPatrol.Service
end
