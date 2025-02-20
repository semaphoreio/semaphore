defmodule InternalApi.Branch.Branch.Type do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :BRANCH, 0
  field :TAG, 1
  field :PR, 2
end

defmodule InternalApi.Branch.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :branch_id, 1, type: :string, json_name: "branchId"
  field :branch_name, 2, type: :string, json_name: "branchName"
  field :project_id, 3, type: :string, json_name: "projectId"
end

defmodule InternalApi.Branch.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :branch, 12, type: InternalApi.Branch.Branch
  field :branch_id, 2, type: :string, json_name: "branchId"
  field :branch_name, 3, type: :string, json_name: "branchName"
  field :project_id, 4, type: :string, json_name: "projectId"
  field :repo_host_url, 5, type: :string, json_name: "repoHostUrl"
  field :tag_name, 6, type: :string, json_name: "tagName"
  field :pr_number, 7, type: :string, json_name: "prNumber"
  field :pr_name, 8, type: :string, json_name: "prName"
  field :type, 9, type: InternalApi.Branch.Branch.Type, enum: true
  field :archived_at, 10, type: Google.Protobuf.Timestamp, json_name: "archivedAt"
  field :display_name, 11, type: :string, json_name: "displayName"
end

defmodule InternalApi.Branch.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :page, 2, type: :int32
  field :page_size, 3, type: :int32, json_name: "pageSize"
  field :with_archived, 4, type: :bool, json_name: "withArchived"
  field :types, 5, repeated: true, type: InternalApi.Branch.Branch.Type, enum: true
  field :name_contains, 6, type: :string, json_name: "nameContains"
end

defmodule InternalApi.Branch.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :branches, 2, repeated: true, type: InternalApi.Branch.Branch
  field :page_number, 3, type: :int32, json_name: "pageNumber"
  field :page_size, 4, type: :int32, json_name: "pageSize"
  field :total_entries, 5, type: :int32, json_name: "totalEntries"
  field :total_pages, 6, type: :int32, json_name: "totalPages"
end

defmodule InternalApi.Branch.FindOrCreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :repository_id, 2, type: :string, json_name: "repositoryId"
  field :name, 3, type: :string
  field :display_name, 4, type: :string, json_name: "displayName"
  field :ref_type, 5, type: InternalApi.Branch.Branch.Type, json_name: "refType", enum: true
  field :pr_name, 6, type: :string, json_name: "prName"
  field :pr_number, 7, type: :int32, json_name: "prNumber"
end

defmodule InternalApi.Branch.FindOrCreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :branch, 2, type: InternalApi.Branch.Branch
end

defmodule InternalApi.Branch.ArchiveRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :branch_id, 1, type: :string, json_name: "branchId"
  field :requested_at, 2, type: Google.Protobuf.Timestamp, json_name: "requestedAt"
end

defmodule InternalApi.Branch.ArchiveResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Branch.FilterRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :name_contains, 2, type: :string, json_name: "nameContains"
  field :page, 3, type: :int32
  field :page_size, 4, type: :int32, json_name: "pageSize"
end

defmodule InternalApi.Branch.FilterResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :branches, 1, repeated: true, type: InternalApi.Branch.Branch

  field :pull_requests, 2,
    repeated: true,
    type: InternalApi.Branch.Branch,
    json_name: "pullRequests"

  field :page_number, 3, type: :int32, json_name: "pageNumber"
  field :page_size, 4, type: :int32, json_name: "pageSize"
  field :total_entries, 5, type: :int32, json_name: "totalEntries"
  field :total_pages, 6, type: :int32, json_name: "totalPages"
end

defmodule InternalApi.Branch.Branch do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 2, type: :string
  field :name, 3, type: :string
  field :project_id, 4, type: :string, json_name: "projectId"
  field :repo_host_url, 5, type: :string, json_name: "repoHostUrl"
  field :tag_name, 6, type: :string, json_name: "tagName"
  field :pr_number, 7, type: :string, json_name: "prNumber"
  field :pr_name, 8, type: :string, json_name: "prName"
  field :type, 9, type: InternalApi.Branch.Branch.Type, enum: true
  field :archived_at, 10, type: Google.Protobuf.Timestamp, json_name: "archivedAt"
  field :display_name, 11, type: :string, json_name: "displayName"
end

defmodule InternalApi.Branch.BranchService.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Branch.BranchService", protoc_gen_elixir_version: "0.13.0"

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