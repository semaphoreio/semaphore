defmodule InternalApi.PermissionPatrol.HasPermissionsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :project_id, 3, type: :string, json_name: "projectId"
  field :permissions, 4, repeated: true, type: :string
end

defmodule InternalApi.PermissionPatrol.HasPermissionsResponse.HasPermissionsEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :bool
end

defmodule InternalApi.PermissionPatrol.HasPermissionsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :has_permissions, 1,
    repeated: true,
    type: InternalApi.PermissionPatrol.HasPermissionsResponse.HasPermissionsEntry,
    json_name: "hasPermissions",
    map: true
end

defmodule InternalApi.PermissionPatrol.PermissionPatrol.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.PermissionPatrol.PermissionPatrol",
    protoc_gen_elixir_version: "0.14.1"

  rpc :HasPermissions,
      InternalApi.PermissionPatrol.HasPermissionsRequest,
      InternalApi.PermissionPatrol.HasPermissionsResponse
end

defmodule InternalApi.PermissionPatrol.PermissionPatrol.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.PermissionPatrol.PermissionPatrol.Service
end
