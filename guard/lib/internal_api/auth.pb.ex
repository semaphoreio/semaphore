defmodule InternalApi.Auth.AuthenticateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          token: String.t()
        }

  defstruct [:token]
  field(:token, 1, type: :string)
end

defmodule InternalApi.Auth.AuthenticateWithCookieRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cookie: String.t(),
          remember_user_token: String.t()
        }

  defstruct [:cookie, :remember_user_token]
  field(:cookie, 1, type: :string)
  field(:remember_user_token, 2, type: :string)
end

defmodule InternalApi.Auth.AuthenticateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          authenticated: boolean,
          name: String.t(),
          user_id: String.t(),
          id_provider: integer,
          ip_address: String.t(),
          user_agent: String.t(),
          error_reason: String.t()
        }

  defstruct [
    :authenticated,
    :name,
    :user_id,
    :id_provider,
    :ip_address,
    :user_agent,
    :error_reason
  ]

  field(:authenticated, 1, type: :bool)
  field(:name, 3, type: :string)
  field(:user_id, 4, type: :string)
  field(:id_provider, 5, type: InternalApi.Auth.IdProvider, enum: true)
  field(:ip_address, 6, type: :string)
  field(:user_agent, 7, type: :string)
  field(:error_reason, 8, type: :string)
end

defmodule InternalApi.Auth.IdProvider do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ID_PROVIDER_UNSPECIFIED, 0)

  field(:ID_PROVIDER_API_TOKEN, 1)

  field(:ID_PROVIDER_GITHUB, 2)

  field(:ID_PROVIDER_BITBUCKET, 3)

  field(:ID_PROVIDER_GITLAB, 4)

  field(:ID_PROVIDER_OKTA, 5)

  field(:ID_PROVIDER_REMEMBER_ME_TOKEN, 6)

  field(:ID_PROVIDER_OIDC, 7)

  field(:ID_PROVIDER_ROOT, 8)
end

defmodule InternalApi.Auth.Authentication.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Auth.Authentication"

  rpc(:Authenticate, InternalApi.Auth.AuthenticateRequest, InternalApi.Auth.AuthenticateResponse)

  rpc(
    :AuthenticateWithCookie,
    InternalApi.Auth.AuthenticateWithCookieRequest,
    InternalApi.Auth.AuthenticateResponse
  )
end

defmodule InternalApi.Auth.Authentication.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Auth.Authentication.Service
end
