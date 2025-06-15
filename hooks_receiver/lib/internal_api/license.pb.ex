defmodule InternalApi.License.VerifyLicenseRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.License.VerifyLicenseResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:valid, 1, type: :bool)
  field(:expires_at, 2, type: Google.Protobuf.Timestamp, json_name: "expiresAt")
  field(:max_users, 3, type: :int32, json_name: "maxUsers")
  field(:enabled_features, 4, repeated: true, type: :string, json_name: "enabledFeatures")
  field(:message, 5, type: :string)
end

defmodule InternalApi.License.LicenseService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.License.LicenseService",
    protoc_gen_elixir_version: "0.13.0"

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
