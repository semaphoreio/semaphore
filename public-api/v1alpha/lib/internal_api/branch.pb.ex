defmodule InternalApi.Branch.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          branch_id: String.t(),
          branch_name: String.t(),
          project_id: String.t()
        }
  defstruct [:branch_id, :branch_name, :project_id]

  field :branch_id, 1, type: :string
  field :branch_name, 2, type: :string
  field :project_id, 3, type: :string
end

defmodule InternalApi.Branch.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          branch: InternalApi.Branch.Branch.t(),
          branch_id: String.t(),
          branch_name: String.t(),
          project_id: String.t(),
          repo_host_url: String.t(),
          tag_name: String.t(),
          pr_number: String.t(),
          pr_name: String.t(),
          type: integer,
          archived_at: Google.Protobuf.Timestamp.t(),
          display_name: String.t()
        }
  defstruct [
    :status,
    :branch,
    :branch_id,
    :branch_name,
    :project_id,
    :repo_host_url,
    :tag_name,
    :pr_number,
    :pr_name,
    :type,
    :archived_at,
    :display_name
  ]

  field :status, 1, type: InternalApi.ResponseStatus
  field :branch, 12, type: InternalApi.Branch.Branch
  field :branch_id, 2, type: :string
  field :branch_name, 3, type: :string
  field :project_id, 4, type: :string
  field :repo_host_url, 5, type: :string
  field :tag_name, 6, type: :string
  field :pr_number, 7, type: :string
  field :pr_name, 8, type: :string
  field :type, 9, type: InternalApi.Branch.Branch.Type, enum: true
  field :archived_at, 10, type: Google.Protobuf.Timestamp
  field :display_name, 11, type: :string
end

defmodule InternalApi.Branch.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          page: integer,
          page_size: integer,
          with_archived: boolean,
          types: [integer],
          name_contains: String.t()
        }
  defstruct [:project_id, :page, :page_size, :with_archived, :types, :name_contains]

  field :project_id, 1, type: :string
  field :page, 2, type: :int32
  field :page_size, 3, type: :int32
  field :with_archived, 4, type: :bool
  field :types, 5, repeated: true, type: InternalApi.Branch.Branch.Type, enum: true
  field :name_contains, 6, type: :string
end

defmodule InternalApi.Branch.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          branches: [InternalApi.Branch.Branch.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:status, :branches, :page_number, :page_size, :total_entries, :total_pages]

  field :status, 1, type: InternalApi.ResponseStatus
  field :branches, 2, repeated: true, type: InternalApi.Branch.Branch
  field :page_number, 3, type: :int32
  field :page_size, 4, type: :int32
  field :total_entries, 5, type: :int32
  field :total_pages, 6, type: :int32
end

defmodule InternalApi.Branch.FindOrCreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          repository_id: String.t(),
          name: String.t(),
          display_name: String.t(),
          ref_type: integer,
          pr_name: String.t(),
          pr_number: integer
        }
  defstruct [:project_id, :repository_id, :name, :display_name, :ref_type, :pr_name, :pr_number]

  field :project_id, 1, type: :string
  field :repository_id, 2, type: :string
  field :name, 3, type: :string
  field :display_name, 4, type: :string
  field :ref_type, 5, type: InternalApi.Branch.Branch.Type, enum: true
  field :pr_name, 6, type: :string
  field :pr_number, 7, type: :int32
end

defmodule InternalApi.Branch.FindOrCreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          branch: InternalApi.Branch.Branch.t()
        }
  defstruct [:status, :branch]

  field :status, 1, type: InternalApi.ResponseStatus
  field :branch, 2, type: InternalApi.Branch.Branch
end

defmodule InternalApi.Branch.ArchiveRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          branch_id: String.t(),
          requested_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:branch_id, :requested_at]

  field :branch_id, 1, type: :string
  field :requested_at, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Branch.ArchiveResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:status]

  field :status, 1, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Branch.FilterRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          name_contains: String.t(),
          page: integer,
          page_size: integer
        }
  defstruct [:project_id, :name_contains, :page, :page_size]

  field :project_id, 1, type: :string
  field :name_contains, 2, type: :string
  field :page, 3, type: :int32
  field :page_size, 4, type: :int32
end

defmodule InternalApi.Branch.FilterResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          branches: [InternalApi.Branch.Branch.t()],
          pull_requests: [InternalApi.Branch.Branch.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:branches, :pull_requests, :page_number, :page_size, :total_entries, :total_pages]

  field :branches, 1, repeated: true, type: InternalApi.Branch.Branch
  field :pull_requests, 2, repeated: true, type: InternalApi.Branch.Branch
  field :page_number, 3, type: :int32
  field :page_size, 4, type: :int32
  field :total_entries, 5, type: :int32
  field :total_pages, 6, type: :int32
end

defmodule InternalApi.Branch.Branch do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          project_id: String.t(),
          repo_host_url: String.t(),
          tag_name: String.t(),
          pr_number: String.t(),
          pr_name: String.t(),
          type: integer,
          archived_at: Google.Protobuf.Timestamp.t(),
          display_name: String.t()
        }
  defstruct [
    :id,
    :name,
    :project_id,
    :repo_host_url,
    :tag_name,
    :pr_number,
    :pr_name,
    :type,
    :archived_at,
    :display_name
  ]

  field :id, 2, type: :string
  field :name, 3, type: :string
  field :project_id, 4, type: :string
  field :repo_host_url, 5, type: :string
  field :tag_name, 6, type: :string
  field :pr_number, 7, type: :string
  field :pr_name, 8, type: :string
  field :type, 9, type: InternalApi.Branch.Branch.Type, enum: true
  field :archived_at, 10, type: Google.Protobuf.Timestamp
  field :display_name, 11, type: :string
end

defmodule InternalApi.Branch.Branch.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :BRANCH, 0
  field :TAG, 1
  field :PR, 2
end

defmodule InternalApi.Branch.BranchService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Branch.BranchService"

  rpc :Describe, InternalApi.Branch.DescribeRequest, InternalApi.Branch.DescribeResponse
  rpc :List, InternalApi.Branch.ListRequest, InternalApi.Branch.ListResponse

  rpc :FindOrCreate,
      InternalApi.Branch.FindOrCreateRequest,
      InternalApi.Branch.FindOrCreateResponse

  rpc :Archive, InternalApi.Branch.ArchiveRequest, InternalApi.Branch.ArchiveResponse
  rpc :Filter, InternalApi.Branch.FilterRequest, InternalApi.Branch.FilterResponse
end

defmodule InternalApi.Branch.BranchService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Branch.BranchService.Service
end
