defmodule InternalApi.Auth.IdProvider do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :ID_PROVIDER_UNSPECIFIED, 0
  field :ID_PROVIDER_API_TOKEN, 1
  field :ID_PROVIDER_GITHUB, 2
  field :ID_PROVIDER_BITBUCKET, 3
  field :ID_PROVIDER_GITLAB, 4
  field :ID_PROVIDER_OKTA, 5
  field :ID_PROVIDER_REMEMBER_ME_TOKEN, 6
  field :ID_PROVIDER_OIDC, 7
  field :ID_PROVIDER_ROOT, 8
end

defmodule InternalApi.Auth.AuthenticateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :token, 1, type: :string
end

defmodule InternalApi.Auth.AuthenticateWithCookieRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :cookie, 1, type: :string
  field :remember_user_token, 2, type: :string, json_name: "rememberUserToken"
end

defmodule InternalApi.Auth.AuthenticateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :authenticated, 1, type: :bool
  field :name, 3, type: :string
  field :user_id, 4, type: :string, json_name: "userId"
  field :id_provider, 5, type: InternalApi.Auth.IdProvider, json_name: "idProvider", enum: true
  field :ip_address, 6, type: :string, json_name: "ipAddress"
  field :user_agent, 7, type: :string, json_name: "userAgent"
end

defmodule InternalApi.Auth.Authentication.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Auth.Authentication", protoc_gen_elixir_version: "0.12.0"

  rpc :Authenticate, InternalApi.Auth.AuthenticateRequest, InternalApi.Auth.AuthenticateResponse

  rpc :AuthenticateWithCookie,
      InternalApi.Auth.AuthenticateWithCookieRequest,
      InternalApi.Auth.AuthenticateResponse
end

defmodule InternalApi.Auth.Authentication.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Auth.Authentication.Service
end