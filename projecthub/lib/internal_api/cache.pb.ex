defmodule InternalApi.Cache.CreateRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3
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

defmodule InternalApi.Cache.Cache do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:id, 1, type: :string)
  field(:credential, 2, type: :string)
  field(:url, 3, type: :string)
end

defmodule InternalApi.Cache.CacheService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Cache.CacheService", protoc_gen_elixir_version: "0.11.0"

  rpc(:Create, InternalApi.Cache.CreateRequest, InternalApi.Cache.CreateResponse)

  rpc(:Describe, InternalApi.Cache.DescribeRequest, InternalApi.Cache.DescribeResponse)

  rpc(:Destroy, InternalApi.Cache.DestroyRequest, InternalApi.Cache.DestroyResponse)

  rpc(:Update, InternalApi.Cache.UpdateRequest, InternalApi.Cache.UpdateResponse)
end

defmodule InternalApi.Cache.CacheService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Cache.CacheService.Service
end
