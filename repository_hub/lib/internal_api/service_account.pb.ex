defmodule InternalApi.ServiceAccount.CreateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :org_id, 1, type: :string, json_name: "orgId"
  field :name, 2, type: :string
  field :description, 3, type: :string
  field :creator_id, 4, type: :string, json_name: "creatorId"
end

defmodule InternalApi.ServiceAccount.CreateResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account, 1,
    type: InternalApi.ServiceAccount.ServiceAccount,
    json_name: "serviceAccount"

  field :api_token, 2, type: :string, json_name: "apiToken"
end

defmodule InternalApi.ServiceAccount.ListRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :org_id, 1, type: :string, json_name: "orgId"
  field :page_size, 2, type: :int32, json_name: "pageSize"
  field :page_token, 3, type: :string, json_name: "pageToken"
end

defmodule InternalApi.ServiceAccount.ListResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_accounts, 1,
    repeated: true,
    type: InternalApi.ServiceAccount.ServiceAccount,
    json_name: "serviceAccounts"

  field :next_page_token, 2, type: :string, json_name: "nextPageToken"
end

defmodule InternalApi.ServiceAccount.DescribeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account_id, 1, type: :string, json_name: "serviceAccountId"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.ServiceAccount.DescribeResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account, 1,
    type: InternalApi.ServiceAccount.ServiceAccount,
    json_name: "serviceAccount"
end

defmodule InternalApi.ServiceAccount.DescribeManyRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :sa_ids, 1, repeated: true, type: :string, json_name: "saIds"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.ServiceAccount.DescribeManyResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_accounts, 1,
    repeated: true,
    type: InternalApi.ServiceAccount.ServiceAccount,
    json_name: "serviceAccounts"
end

defmodule InternalApi.ServiceAccount.UpdateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account_id, 1, type: :string, json_name: "serviceAccountId"
  field :name, 2, type: :string
  field :description, 3, type: :string
  field :org_id, 4, type: :string, json_name: "orgId"
end

defmodule InternalApi.ServiceAccount.UpdateResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account, 1,
    type: InternalApi.ServiceAccount.ServiceAccount,
    json_name: "serviceAccount"
end

defmodule InternalApi.ServiceAccount.DeactivateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account_id, 1, type: :string, json_name: "serviceAccountId"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.ServiceAccount.DeactivateResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3
end

defmodule InternalApi.ServiceAccount.ReactivateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account_id, 1, type: :string, json_name: "serviceAccountId"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.ServiceAccount.ReactivateResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3
end

defmodule InternalApi.ServiceAccount.DestroyRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account_id, 1, type: :string, json_name: "serviceAccountId"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.ServiceAccount.DestroyResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3
end

defmodule InternalApi.ServiceAccount.RegenerateTokenRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account_id, 1, type: :string, json_name: "serviceAccountId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :requester_id, 3, type: :string, json_name: "requesterId"
end

defmodule InternalApi.ServiceAccount.RegenerateTokenResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :api_token, 1, type: :string, json_name: "apiToken"
end

defmodule InternalApi.ServiceAccount.SetOwnerRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account_id, 1, type: :string, json_name: "serviceAccountId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :owner_id, 3, type: :string, json_name: "ownerId"
  field :requester_id, 4, type: :string, json_name: "requesterId"
end

defmodule InternalApi.ServiceAccount.SetOwnerResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account, 1,
    type: InternalApi.ServiceAccount.ServiceAccount,
    json_name: "serviceAccount"
end

defmodule InternalApi.ServiceAccount.ReleaseOwnerRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account_id, 1, type: :string, json_name: "serviceAccountId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :requester_id, 3, type: :string, json_name: "requesterId"
end

defmodule InternalApi.ServiceAccount.ReleaseOwnerResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :service_account, 1,
    type: InternalApi.ServiceAccount.ServiceAccount,
    json_name: "serviceAccount"
end

defmodule InternalApi.ServiceAccount.ServiceAccount do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :description, 3, type: :string
  field :org_id, 4, type: :string, json_name: "orgId"
  field :creator_id, 5, type: :string, json_name: "creatorId"
  field :created_at, 6, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :updated_at, 7, type: Google.Protobuf.Timestamp, json_name: "updatedAt"
  field :deactivated, 8, type: :bool
  field :owner_id, 9, type: :string, json_name: "ownerId"
  field :owner_active, 10, type: :bool, json_name: "ownerActive"
end

defmodule InternalApi.ServiceAccount.ServiceAccountService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.ServiceAccount.ServiceAccountService",
    protoc_gen_elixir_version: "0.14.0"

  rpc :Create,
      InternalApi.ServiceAccount.CreateRequest,
      InternalApi.ServiceAccount.CreateResponse

  rpc :List, InternalApi.ServiceAccount.ListRequest, InternalApi.ServiceAccount.ListResponse

  rpc :Describe,
      InternalApi.ServiceAccount.DescribeRequest,
      InternalApi.ServiceAccount.DescribeResponse

  rpc :DescribeMany,
      InternalApi.ServiceAccount.DescribeManyRequest,
      InternalApi.ServiceAccount.DescribeManyResponse

  rpc :Update,
      InternalApi.ServiceAccount.UpdateRequest,
      InternalApi.ServiceAccount.UpdateResponse

  rpc :Deactivate,
      InternalApi.ServiceAccount.DeactivateRequest,
      InternalApi.ServiceAccount.DeactivateResponse

  rpc :Reactivate,
      InternalApi.ServiceAccount.ReactivateRequest,
      InternalApi.ServiceAccount.ReactivateResponse

  rpc :Destroy,
      InternalApi.ServiceAccount.DestroyRequest,
      InternalApi.ServiceAccount.DestroyResponse

  rpc :RegenerateToken,
      InternalApi.ServiceAccount.RegenerateTokenRequest,
      InternalApi.ServiceAccount.RegenerateTokenResponse

  rpc :SetOwner,
      InternalApi.ServiceAccount.SetOwnerRequest,
      InternalApi.ServiceAccount.SetOwnerResponse

  rpc :ReleaseOwner,
      InternalApi.ServiceAccount.ReleaseOwnerRequest,
      InternalApi.ServiceAccount.ReleaseOwnerResponse
end

defmodule InternalApi.ServiceAccount.ServiceAccountService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.ServiceAccount.ServiceAccountService.Service
end
