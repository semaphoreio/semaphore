defmodule InternalApi.Okta.OktaIntegration do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          org_id: String.t(),
          creator_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          updated_at: Google.Protobuf.Timestamp.t(),
          idempotency_token: String.t(),
          saml_issuer: String.t(),
          sso_url: String.t(),
          jit_provisioning_enabled: boolean,
          session_expiration_minutes: integer
        }

  defstruct [
    :id,
    :org_id,
    :creator_id,
    :created_at,
    :updated_at,
    :idempotency_token,
    :saml_issuer,
    :sso_url,
    :jit_provisioning_enabled,
    :session_expiration_minutes
  ]

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:creator_id, 3, type: :string)
  field(:created_at, 4, type: Google.Protobuf.Timestamp)
  field(:updated_at, 5, type: Google.Protobuf.Timestamp)
  field(:idempotency_token, 6, type: :string)
  field(:saml_issuer, 7, type: :string)
  field(:sso_url, 8, type: :string)
  field(:jit_provisioning_enabled, 9, type: :bool)
  field(:session_expiration_minutes, 10, type: :int32)
end

defmodule InternalApi.Okta.SetUpRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          idempotency_token: String.t(),
          org_id: String.t(),
          creator_id: String.t(),
          saml_certificate: String.t(),
          saml_issuer: String.t(),
          sso_url: String.t(),
          jit_provisioning_enabled: boolean,
          session_expiration_minutes: integer
        }

  defstruct [
    :idempotency_token,
    :org_id,
    :creator_id,
    :saml_certificate,
    :saml_issuer,
    :sso_url,
    :jit_provisioning_enabled,
    :session_expiration_minutes
  ]

  field(:idempotency_token, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:creator_id, 3, type: :string)
  field(:saml_certificate, 4, type: :string)
  field(:saml_issuer, 5, type: :string)
  field(:sso_url, 6, type: :string)
  field(:jit_provisioning_enabled, 7, type: :bool)
  field(:session_expiration_minutes, 8, type: :int32)
end

defmodule InternalApi.Okta.SetUpResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          integration: InternalApi.Okta.OktaIntegration.t()
        }

  defstruct [:integration]
  field(:integration, 1, type: InternalApi.Okta.OktaIntegration)
end

defmodule InternalApi.Okta.GenerateScimTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          integration_id: String.t()
        }

  defstruct [:integration_id]
  field(:integration_id, 1, type: :string)
end

defmodule InternalApi.Okta.GenerateScimTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          token: String.t()
        }

  defstruct [:token]
  field(:token, 1, type: :string)
end

defmodule InternalApi.Okta.SetUpMappingRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          default_role_id: String.t(),
          group_mapping: [InternalApi.Okta.GroupMapping.t()],
          role_mapping: [InternalApi.Okta.RoleMapping.t()]
        }

  defstruct [:org_id, :default_role_id, :group_mapping, :role_mapping]
  field(:org_id, 1, type: :string)
  field(:default_role_id, 2, type: :string)
  field(:group_mapping, 3, repeated: true, type: InternalApi.Okta.GroupMapping)
  field(:role_mapping, 4, repeated: true, type: InternalApi.Okta.RoleMapping)
end

defmodule InternalApi.Okta.SetUpMappingResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Okta.DescribeMappingRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct [:org_id]
  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Okta.DescribeMappingResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          default_role_id: String.t(),
          group_mapping: [InternalApi.Okta.GroupMapping.t()],
          role_mapping: [InternalApi.Okta.RoleMapping.t()]
        }

  defstruct [:default_role_id, :group_mapping, :role_mapping]
  field(:default_role_id, 1, type: :string)
  field(:group_mapping, 2, repeated: true, type: InternalApi.Okta.GroupMapping)
  field(:role_mapping, 3, repeated: true, type: InternalApi.Okta.RoleMapping)
end

defmodule InternalApi.Okta.GroupMapping do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          semaphore_group_id: String.t(),
          okta_group_id: String.t()
        }

  defstruct [:semaphore_group_id, :okta_group_id]
  field(:semaphore_group_id, 1, type: :string)
  field(:okta_group_id, 2, type: :string)
end

defmodule InternalApi.Okta.RoleMapping do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          semaphore_role_id: String.t(),
          okta_role_id: String.t()
        }

  defstruct [:semaphore_role_id, :okta_role_id]
  field(:semaphore_role_id, 1, type: :string)
  field(:okta_role_id, 2, type: :string)
end

defmodule InternalApi.Okta.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct [:org_id]
  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Okta.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          integrations: [InternalApi.Okta.OktaIntegration.t()]
        }

  defstruct [:integrations]
  field(:integrations, 1, repeated: true, type: InternalApi.Okta.OktaIntegration)
end

defmodule InternalApi.Okta.ListUsersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct [:org_id]
  field(:org_id, 1, type: :string)
end

defmodule InternalApi.Okta.ListUsersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_ids: [String.t()]
        }

  defstruct [:user_ids]
  field(:user_ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.Okta.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          integration_id: String.t(),
          user_id: String.t()
        }

  defstruct [:integration_id, :user_id]
  field(:integration_id, 1, type: :string)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.Okta.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Okta.Okta.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Okta.Okta"

  rpc(:SetUp, InternalApi.Okta.SetUpRequest, InternalApi.Okta.SetUpResponse)

  rpc(
    :GenerateScimToken,
    InternalApi.Okta.GenerateScimTokenRequest,
    InternalApi.Okta.GenerateScimTokenResponse
  )

  rpc(:List, InternalApi.Okta.ListRequest, InternalApi.Okta.ListResponse)

  rpc(:ListUsers, InternalApi.Okta.ListUsersRequest, InternalApi.Okta.ListUsersResponse)

  rpc(:Destroy, InternalApi.Okta.DestroyRequest, InternalApi.Okta.DestroyResponse)

  rpc(:SetUpMapping, InternalApi.Okta.SetUpMappingRequest, InternalApi.Okta.SetUpMappingResponse)

  rpc(
    :DescribeMapping,
    InternalApi.Okta.DescribeMappingRequest,
    InternalApi.Okta.DescribeMappingResponse
  )
end

defmodule InternalApi.Okta.Okta.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Okta.Okta.Service
end
