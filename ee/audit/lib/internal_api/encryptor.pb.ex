defmodule InternalApi.Encryptor.EncryptRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          raw: binary,
          associated_data: binary
        }

  defstruct [:raw, :associated_data]

  field(:raw, 1, type: :bytes)
  field(:associated_data, 2, type: :bytes)
end

defmodule InternalApi.Encryptor.EncryptResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cypher: binary
        }

  defstruct [:cypher]

  field(:cypher, 1, type: :bytes)
end

defmodule InternalApi.Encryptor.DecryptRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cypher: binary,
          associated_data: binary
        }

  defstruct [:cypher, :associated_data]

  field(:cypher, 1, type: :bytes)
  field(:associated_data, 2, type: :bytes)
end

defmodule InternalApi.Encryptor.DecryptResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          raw: binary
        }

  defstruct [:raw]

  field(:raw, 1, type: :bytes)
end

defmodule InternalApi.Encryptor.Encryptor.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Encryptor.Encryptor"

  rpc(:Encrypt, InternalApi.Encryptor.EncryptRequest, InternalApi.Encryptor.EncryptResponse)

  rpc(:Decrypt, InternalApi.Encryptor.DecryptRequest, InternalApi.Encryptor.DecryptResponse)
end

defmodule InternalApi.Encryptor.Encryptor.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Encryptor.Encryptor.Service
end
