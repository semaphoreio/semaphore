defmodule InternalApi.Encryptor.EncryptRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :raw, 1, type: :bytes
  field :associated_data, 2, type: :bytes, json_name: "associatedData"
end

defmodule InternalApi.Encryptor.EncryptResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :cypher, 1, type: :bytes
end

defmodule InternalApi.Encryptor.DecryptRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :cypher, 1, type: :bytes
  field :associated_data, 2, type: :bytes, json_name: "associatedData"
end

defmodule InternalApi.Encryptor.DecryptResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :raw, 1, type: :bytes
end

defmodule InternalApi.Encryptor.Encryptor.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Encryptor.Encryptor", protoc_gen_elixir_version: "0.14.0"

  rpc :Encrypt, InternalApi.Encryptor.EncryptRequest, InternalApi.Encryptor.EncryptResponse

  rpc :Decrypt, InternalApi.Encryptor.DecryptRequest, InternalApi.Encryptor.DecryptResponse
end

defmodule InternalApi.Encryptor.Encryptor.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Encryptor.Encryptor.Service
end
