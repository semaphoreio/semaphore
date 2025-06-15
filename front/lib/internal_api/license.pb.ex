defmodule InternalApi.License.VerifyLicenseRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.License.VerifyLicenseResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          valid: boolean,
          expires_at: Google.Protobuf.Timestamp.t(),
          max_users: integer,
          enabled_features: [String.t()],
          message: String.t()
        }
  defstruct [:valid, :expires_at, :max_users, :enabled_features, :message]

  field(:valid, 1, type: :bool)
  field(:expires_at, 2, type: Google.Protobuf.Timestamp)
  field(:max_users, 3, type: :int32)
  field(:enabled_features, 4, repeated: true, type: :string)
  field(:message, 5, type: :string)
end

defmodule InternalApi.License.LicenseService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.License.LicenseService"

  rpc(
    :VerifyLicense,
    InternalApi.License.VerifyLicenseRequest,
    InternalApi.License.VerifyLicenseResponse
  )
end

defmodule InternalApi.License.LicenseService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.License.LicenseService.Service
end
