defmodule InternalApi.Groups.ListGroupsRequest.Page do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:page_no, 1, type: :int32, json_name: "pageNo")
  field(:page_size, 2, type: :int32, json_name: "pageSize")
end

defmodule InternalApi.Groups.ListGroupsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:group_id, 2, type: :string, json_name: "groupId")
  field(:page, 3, type: InternalApi.Groups.ListGroupsRequest.Page)
end

defmodule InternalApi.Groups.ListGroupsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:groups, 1, repeated: true, type: InternalApi.Groups.Group)
  field(:total_pages, 2, type: :int32, json_name: "totalPages")
end

defmodule InternalApi.Groups.CreateGroupRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:group, 1, type: InternalApi.Groups.Group)
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:requester_id, 3, type: :string, json_name: "requesterId")
end

defmodule InternalApi.Groups.CreateGroupResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:group, 1, type: InternalApi.Groups.Group)
end

defmodule InternalApi.Groups.DestroyGroupRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:group_id, 1, type: :string, json_name: "groupId")
  field(:requester_id, 2, type: :string, json_name: "requesterId")
end

defmodule InternalApi.Groups.DestroyGroupResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Groups.ModifyGroupRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:group, 1, type: InternalApi.Groups.Group)
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:requester_id, 3, type: :string, json_name: "requesterId")
  field(:members_to_add, 4, repeated: true, type: :string, json_name: "membersToAdd")
  field(:members_to_remove, 5, repeated: true, type: :string, json_name: "membersToRemove")
end

defmodule InternalApi.Groups.ModifyGroupResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:group, 1, type: InternalApi.Groups.Group)
end

defmodule InternalApi.Groups.Group do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:member_ids, 4, repeated: true, type: :string, json_name: "memberIds")
end

defmodule InternalApi.Groups.Groups.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Groups.Groups", protoc_gen_elixir_version: "0.13.0"

  rpc(:ListGroups, InternalApi.Groups.ListGroupsRequest, InternalApi.Groups.ListGroupsResponse)

  rpc(:CreateGroup, InternalApi.Groups.CreateGroupRequest, InternalApi.Groups.CreateGroupResponse)

  rpc(
    :DestroyGroup,
    InternalApi.Groups.DestroyGroupRequest,
    InternalApi.Groups.DestroyGroupResponse
  )

  rpc(:ModifyGroup, InternalApi.Groups.ModifyGroupRequest, InternalApi.Groups.ModifyGroupResponse)
end

defmodule InternalApi.Groups.Groups.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Groups.Groups.Service
end
