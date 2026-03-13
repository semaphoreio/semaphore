defmodule InternalApi.Cache.CacheState do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:CACHE_STATE_UNSPECIFIED, 0)
  field(:PROVISIONING, 1)
  field(:READY, 2)
  field(:FAILED, 3)
  field(:UNAVAILABLE, 4)
  field(:DELETING, 5)
end

defmodule InternalApi.Cache.Backend do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:BACKEND_UNSPECIFIED, 0)
  field(:SFTP, 1)
  field(:CEPH, 2)
end

defmodule InternalApi.Cache.CreateRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:organization_name, 3, type: :string, json_name: "organizationName")
  field(:project_name, 4, type: :string, json_name: "projectName")
  field(:backend, 5, type: InternalApi.Cache.Backend, enum: true)
end

defmodule InternalApi.Cache.CreateResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache_id, 1, type: :string, json_name: "cacheId")
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.DescribeRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache_id, 1, type: :string, json_name: "cacheId")
end

defmodule InternalApi.Cache.DescribeResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache, 1, type: InternalApi.Cache.Cache)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.DestroyRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache_id, 1, type: :string, json_name: "cacheId")
end

defmodule InternalApi.Cache.DestroyResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.UpdateRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache, 1, type: InternalApi.Cache.Cache)
end

defmodule InternalApi.Cache.UpdateResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache, 1, type: InternalApi.Cache.Cache)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.UpdateCacheQuotaRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache_id, 1, type: :string, json_name: "cacheId")
  field(:max_size_bytes, 2, type: :int64, json_name: "maxSizeBytes")
  field(:max_objects, 3, type: :int64, json_name: "maxObjects")
end

defmodule InternalApi.Cache.UpdateCacheQuotaResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache, 1, type: InternalApi.Cache.Cache)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.ProvisionCephCacheRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache_id, 1, type: :string, json_name: "cacheId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
  field(:project_id, 3, type: :string, json_name: "projectId")
  field(:organization_name, 4, type: :string, json_name: "organizationName")
  field(:project_name, 5, type: :string, json_name: "projectName")
end

defmodule InternalApi.Cache.ProvisionCephCacheResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:cache, 1, type: InternalApi.Cache.Cache)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.Cache do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:id, 1, type: :string)
  field(:credential, 2, type: :string)
  field(:url, 3, type: :string)
  field(:bucket, 4, type: :string)
  field(:ro_role_arn, 5, type: :string, json_name: "roRoleArn")
  field(:rw_role_arn, 6, type: :string, json_name: "rwRoleArn")
  field(:state, 7, type: InternalApi.Cache.CacheState, enum: true)
  field(:quota_max_size_bytes, 8, type: :int64, json_name: "quotaMaxSizeBytes")
  field(:quota_max_objects, 9, type: :int64, json_name: "quotaMaxObjects")
  field(:backend, 10, type: InternalApi.Cache.Backend, enum: true)
end

defmodule InternalApi.Cache.CacheService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Cache.CacheService", protoc_gen_elixir_version: "0.11.0"

  rpc(:Create, InternalApi.Cache.CreateRequest, InternalApi.Cache.CreateResponse)

  rpc(:Describe, InternalApi.Cache.DescribeRequest, InternalApi.Cache.DescribeResponse)

  rpc(:Destroy, InternalApi.Cache.DestroyRequest, InternalApi.Cache.DestroyResponse)

  rpc(:Update, InternalApi.Cache.UpdateRequest, InternalApi.Cache.UpdateResponse)

  rpc(
    :UpdateCacheQuota,
    InternalApi.Cache.UpdateCacheQuotaRequest,
    InternalApi.Cache.UpdateCacheQuotaResponse
  )

  rpc(
    :ProvisionCephCache,
    InternalApi.Cache.ProvisionCephCacheRequest,
    InternalApi.Cache.ProvisionCephCacheResponse
  )
end

defmodule InternalApi.Cache.CacheService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Cache.CacheService.Service
end
