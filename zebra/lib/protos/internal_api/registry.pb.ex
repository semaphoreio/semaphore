defmodule InternalApi.Registry.GetCredentialsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          min_validity_seconds: integer
        }
  defstruct [:organization_id, :min_validity_seconds]

  field(:organization_id, 1, type: :string)
  field(:min_validity_seconds, 2, type: :int64)
end

defmodule InternalApi.Registry.GetCredentialsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          host: String.t(),
          repository_prefix: String.t(),
          username: String.t(),
          password: String.t(),
          expires_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:status, :host, :repository_prefix, :username, :password, :expires_at]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:host, 2, type: :string)
  field(:repository_prefix, 3, type: :string)
  field(:username, 4, type: :string)
  field(:password, 5, type: :string)
  field(:expires_at, 6, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Registry.RegistryService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Registry.RegistryService"

  rpc(
    :GetCredentials,
    InternalApi.Registry.GetCredentialsRequest,
    InternalApi.Registry.GetCredentialsResponse
  )
end

defmodule InternalApi.Registry.RegistryService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Registry.RegistryService.Service
end
