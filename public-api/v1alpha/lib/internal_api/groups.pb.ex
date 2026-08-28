defmodule InternalApi.Groups.ListGroupsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          group_id: String.t(),
          page: InternalApi.Groups.ListGroupsRequest.Page.t()
        }
  defstruct [:org_id, :group_id, :page]

  field(:org_id, 1, type: :string)
  field(:group_id, 2, type: :string)
  field(:page, 3, type: InternalApi.Groups.ListGroupsRequest.Page)
end

defmodule InternalApi.Groups.ListGroupsRequest.Page do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_no: integer,
          page_size: integer
        }
  defstruct [:page_no, :page_size]

  field(:page_no, 1, type: :int32)
  field(:page_size, 2, type: :int32)
end

defmodule InternalApi.Groups.ListGroupsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          groups: [InternalApi.Groups.Group.t()],
          total_pages: integer
        }
  defstruct [:groups, :total_pages]

  field(:groups, 1, repeated: true, type: InternalApi.Groups.Group)
  field(:total_pages, 2, type: :int32)
end

defmodule InternalApi.Groups.CreateGroupRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          group: InternalApi.Groups.Group.t(),
          org_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:group, :org_id, :requester_id]

  field(:group, 1, type: InternalApi.Groups.Group)
  field(:org_id, 2, type: :string)
  field(:requester_id, 3, type: :string)
end

defmodule InternalApi.Groups.CreateGroupResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          group: InternalApi.Groups.Group.t()
        }
  defstruct [:group]

  field(:group, 1, type: InternalApi.Groups.Group)
end

defmodule InternalApi.Groups.DestroyGroupRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          group_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:group_id, :requester_id]

  field(:group_id, 1, type: :string)
  field(:requester_id, 2, type: :string)
end

defmodule InternalApi.Groups.DestroyGroupResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Groups.ModifyGroupRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          group: InternalApi.Groups.Group.t(),
          org_id: String.t(),
          requester_id: String.t(),
          members_to_add: [String.t()],
          members_to_remove: [String.t()]
        }
  defstruct [:group, :org_id, :requester_id, :members_to_add, :members_to_remove]

  field(:group, 1, type: InternalApi.Groups.Group)
  field(:org_id, 2, type: :string)
  field(:requester_id, 3, type: :string)
  field(:members_to_add, 4, repeated: true, type: :string)
  field(:members_to_remove, 5, repeated: true, type: :string)
end

defmodule InternalApi.Groups.ModifyGroupResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          group: InternalApi.Groups.Group.t()
        }
  defstruct [:group]

  field(:group, 1, type: InternalApi.Groups.Group)
end

defmodule InternalApi.Groups.Group do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          member_ids: [String.t()]
        }
  defstruct [:id, :name, :description, :member_ids]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:member_ids, 4, repeated: true, type: :string)
end

defmodule InternalApi.Groups.Groups.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Groups.Groups"

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
