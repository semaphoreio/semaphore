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

defmodule InternalApi.Cache.CacheService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Cache.CacheService"

  rpc(:Create, InternalApi.Cache.CreateRequest, InternalApi.Cache.CreateResponse)
  rpc(:Describe, InternalApi.Cache.DescribeRequest, InternalApi.Cache.DescribeResponse)
  rpc(:Destroy, InternalApi.Cache.DestroyRequest, InternalApi.Cache.DestroyResponse)
  rpc(:Update, InternalApi.Cache.UpdateRequest, InternalApi.Cache.UpdateResponse)
end

defmodule InternalApi.Cache.CacheService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Cache.CacheService.Service
end
