defmodule InternalApi.Cache.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          project_id: String.t(),
          organization_name: String.t(),
          project_name: String.t(),
          backend: integer
        }
  defstruct [:organization_id, :project_id, :organization_name, :project_name, :backend]

  field :organization_id, 1, type: :string
  field :project_id, 2, type: :string
  field :organization_name, 3, type: :string
  field :project_name, 4, type: :string
  field :backend, 5, type: InternalApi.Cache.Backend, enum: true
end

defmodule InternalApi.Cache.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache_id: String.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:cache_id, :status]

  field :cache_id, 1, type: :string
  field :status, 2, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Cache.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache_id: String.t()
        }
  defstruct [:cache_id]

  field :cache_id, 1, type: :string
end

defmodule InternalApi.Cache.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache: InternalApi.Cache.Cache.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:cache, :status]

  field :cache, 1, type: InternalApi.Cache.Cache
  field :status, 2, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Cache.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache_id: String.t()
        }
  defstruct [:cache_id]

  field :cache_id, 1, type: :string
end

defmodule InternalApi.Cache.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:status]

  field :status, 2, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Cache.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache: InternalApi.Cache.Cache.t()
        }
  defstruct [:cache]

  field :cache, 1, type: InternalApi.Cache.Cache
end

defmodule InternalApi.Cache.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache: InternalApi.Cache.Cache.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:cache, :status]

  field :cache, 1, type: InternalApi.Cache.Cache
  field :status, 2, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Cache.UpdateCacheQuotaRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache_id: String.t(),
          max_size_bytes: integer,
          max_objects: integer
        }
  defstruct [:cache_id, :max_size_bytes, :max_objects]

  field :cache_id, 1, type: :string
  field :max_size_bytes, 2, type: :int64
  field :max_objects, 3, type: :int64
end

defmodule InternalApi.Cache.UpdateCacheQuotaResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache: InternalApi.Cache.Cache.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:cache, :status]

  field :cache, 1, type: InternalApi.Cache.Cache
  field :status, 2, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Cache.ProvisionCephCacheRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache_id: String.t(),
          organization_id: String.t(),
          project_id: String.t(),
          organization_name: String.t(),
          project_name: String.t()
        }
  defstruct [:cache_id, :organization_id, :project_id, :organization_name, :project_name]

  field :cache_id, 1, type: :string
  field :organization_id, 2, type: :string
  field :project_id, 3, type: :string
  field :organization_name, 4, type: :string
  field :project_name, 5, type: :string
end

defmodule InternalApi.Cache.ProvisionCephCacheResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache: InternalApi.Cache.Cache.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:cache, :status]

  field :cache, 1, type: InternalApi.Cache.Cache
  field :status, 2, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Cache.Cache do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          credential: String.t(),
          url: String.t(),
          bucket: String.t(),
          ro_role_arn: String.t(),
          rw_role_arn: String.t(),
          state: integer,
          quota_max_size_bytes: integer,
          quota_max_objects: integer,
          backend: integer
        }
  defstruct [
    :id,
    :credential,
    :url,
    :bucket,
    :ro_role_arn,
    :rw_role_arn,
    :state,
    :quota_max_size_bytes,
    :quota_max_objects,
    :backend
  ]

  field :id, 1, type: :string
  field :credential, 2, type: :string
  field :url, 3, type: :string
  field :bucket, 4, type: :string
  field :ro_role_arn, 5, type: :string
  field :rw_role_arn, 6, type: :string
  field :state, 7, type: InternalApi.Cache.CacheState, enum: true
  field :quota_max_size_bytes, 8, type: :int64
  field :quota_max_objects, 9, type: :int64
  field :backend, 10, type: InternalApi.Cache.Backend, enum: true
end

defmodule InternalApi.Cache.CacheState do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :CACHE_STATE_UNSPECIFIED, 0
  field :PROVISIONING, 1
  field :READY, 2
  field :FAILED, 3
  field :UNAVAILABLE, 4
  field :DELETING, 5
end

defmodule InternalApi.Cache.Backend do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :BACKEND_UNSPECIFIED, 0
  field :SFTP, 1
  field :CEPH, 2
end

defmodule InternalApi.Cache.CacheService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Cache.CacheService"

  rpc :Create, InternalApi.Cache.CreateRequest, InternalApi.Cache.CreateResponse
  rpc :Describe, InternalApi.Cache.DescribeRequest, InternalApi.Cache.DescribeResponse
  rpc :Destroy, InternalApi.Cache.DestroyRequest, InternalApi.Cache.DestroyResponse
  rpc :Update, InternalApi.Cache.UpdateRequest, InternalApi.Cache.UpdateResponse

  rpc :UpdateCacheQuota,
      InternalApi.Cache.UpdateCacheQuotaRequest,
      InternalApi.Cache.UpdateCacheQuotaResponse

  rpc :ProvisionCephCache,
      InternalApi.Cache.ProvisionCephCacheRequest,
      InternalApi.Cache.ProvisionCephCacheResponse
end

defmodule InternalApi.Cache.CacheService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Cache.CacheService.Service
end
