defmodule InternalApi.Okta.OktaIntegration do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:creator_id, 3, type: :string, json_name: "creatorId")
  field(:created_at, 4, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:updated_at, 5, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
  field(:idempotency_token, 6, type: :string, json_name: "idempotencyToken")
  field(:saml_issuer, 7, type: :string, json_name: "samlIssuer")
  field(:sso_url, 8, type: :string, json_name: "ssoUrl")
end

defmodule InternalApi.Okta.SetUpRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:idempotency_token, 1, type: :string, json_name: "idempotencyToken")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:creator_id, 3, type: :string, json_name: "creatorId")
  field(:saml_certificate, 4, type: :string, json_name: "samlCertificate")
  field(:saml_issuer, 5, type: :string, json_name: "samlIssuer")
  field(:sso_url, 6, type: :string, json_name: "ssoUrl")
end

defmodule InternalApi.Okta.SetUpResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:integration, 1, type: InternalApi.Okta.OktaIntegration)
end

defmodule InternalApi.Okta.GenerateScimTokenRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:integration_id, 1, type: :string, json_name: "integrationId")
end

defmodule InternalApi.Okta.GenerateScimTokenResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:token, 1, type: :string)
end

defmodule InternalApi.Okta.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Okta.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:integrations, 1, repeated: true, type: InternalApi.Okta.OktaIntegration)
end

defmodule InternalApi.Okta.ListUsersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.Okta.ListUsersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_ids, 1, repeated: true, type: :string, json_name: "userIds")
end

defmodule InternalApi.Okta.DestroyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:integration_id, 1, type: :string, json_name: "integrationId")
  field(:user_id, 2, type: :string, json_name: "userId")
end

defmodule InternalApi.Okta.DestroyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Okta.Okta.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Okta.Okta", protoc_gen_elixir_version: "0.13.0"

  rpc(:SetUp, InternalApi.Okta.SetUpRequest, InternalApi.Okta.SetUpResponse)

  rpc(
    :GenerateScimToken,
    InternalApi.Okta.GenerateScimTokenRequest,
    InternalApi.Okta.GenerateScimTokenResponse
  )

  rpc(:List, InternalApi.Okta.ListRequest, InternalApi.Okta.ListResponse)

  rpc(:ListUsers, InternalApi.Okta.ListUsersRequest, InternalApi.Okta.ListUsersResponse)

  rpc(:Destroy, InternalApi.Okta.DestroyRequest, InternalApi.Okta.DestroyResponse)
end

defmodule InternalApi.Okta.Okta.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Okta.Okta.Service
end
