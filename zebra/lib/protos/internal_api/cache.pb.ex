defmodule InternalApi.Cache.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Cache.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache_id: String.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:cache_id, :status]

  field(:cache_id, 1, type: :string)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache_id: String.t()
        }
  defstruct [:cache_id]

  field(:cache_id, 1, type: :string)
end

defmodule InternalApi.Cache.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache: InternalApi.Cache.Cache.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:cache, :status]

  field(:cache, 1, type: InternalApi.Cache.Cache)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache_id: String.t()
        }
  defstruct [:cache_id]

  field(:cache_id, 1, type: :string)
end

defmodule InternalApi.Cache.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:status]

  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache: InternalApi.Cache.Cache.t()
        }
  defstruct [:cache]

  field(:cache, 1, type: InternalApi.Cache.Cache)
end

defmodule InternalApi.Cache.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cache: InternalApi.Cache.Cache.t(),
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:cache, :status]

  field(:cache, 1, type: InternalApi.Cache.Cache)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.Cache.Cache do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          credential: String.t(),
          url: String.t()
        }
  defstruct [:id, :credential, :url]

  field(:id, 1, type: :string)
  field(:credential, 2, type: :string)
  field(:url, 3, type: :string)
end

defmodule InternalApi.Cache.GetS3CredentialsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          min_validity_seconds: integer,
          job_id: String.t(),
          organization_id: String.t(),
          refresh_validity_seconds: integer
        }
  defstruct [
    :project_id,
    :min_validity_seconds,
    :job_id,
    :organization_id,
    :refresh_validity_seconds
  ]

  field(:project_id, 1, type: :string)
  field(:min_validity_seconds, 2, type: :int64)
  field(:job_id, 3, type: :string)
  field(:organization_id, 4, type: :string)
  field(:refresh_validity_seconds, 5, type: :int64)
end

defmodule InternalApi.Cache.GetS3CredentialsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          region: String.t(),
          bucket: String.t(),
          prefix: String.t(),
          access_key_id: String.t(),
          secret_access_key: String.t(),
          session_token: String.t(),
          expires_at: Google.Protobuf.Timestamp.t(),
          refresh_token: String.t(),
          refresh_token_expires_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :status,
    :region,
    :bucket,
    :prefix,
    :access_key_id,
    :secret_access_key,
    :session_token,
    :expires_at,
    :refresh_token,
    :refresh_token_expires_at
  ]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:region, 2, type: :string)
  field(:bucket, 3, type: :string)
  field(:prefix, 4, type: :string)
  field(:access_key_id, 5, type: :string)
  field(:secret_access_key, 6, type: :string)
  field(:session_token, 7, type: :string)
  field(:expires_at, 8, type: Google.Protobuf.Timestamp)
  field(:refresh_token, 9, type: :string)
  field(:refresh_token_expires_at, 10, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Cache.CacheService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Cache.CacheService"

  rpc(:Create, InternalApi.Cache.CreateRequest, InternalApi.Cache.CreateResponse)
  rpc(:Describe, InternalApi.Cache.DescribeRequest, InternalApi.Cache.DescribeResponse)
  rpc(:Destroy, InternalApi.Cache.DestroyRequest, InternalApi.Cache.DestroyResponse)
  rpc(:Update, InternalApi.Cache.UpdateRequest, InternalApi.Cache.UpdateResponse)

  rpc(
    :GetS3Credentials,
    InternalApi.Cache.GetS3CredentialsRequest,
    InternalApi.Cache.GetS3CredentialsResponse
  )
end

defmodule InternalApi.Cache.CacheService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Cache.CacheService.Service
end
