defmodule InternalApi.User.Favorite.Kind do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:PROJECT, 0)
  field(:DASHBOARD, 1)
end

defmodule InternalApi.User.DescribeResponse.RepoScope do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:NONE, 0)
  field(:PUBLIC, 1)
  field(:PRIVATE, 2)
end

defmodule InternalApi.User.RepositoryProvider.Type do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:GITHUB, 0)
  field(:BITBUCKET, 1)
  field(:GITLAB, 2)
end

defmodule InternalApi.User.RepositoryProvider.Scope do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:NONE, 0)
  field(:EMAIL, 1)
  field(:PUBLIC, 2)
  field(:PRIVATE, 3)
end

defmodule InternalApi.User.RepositoryScopes.RepositoryScope.Scope do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:NONE, 0)
  field(:EMAIL, 1)
  field(:PUBLIC, 2)
  field(:PRIVATE, 3)
end

defmodule InternalApi.User.User.CreationSource do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:NOT_SET, 0)
  field(:OKTA, 1)
  field(:SERVICE_ACCOUNT, 2)
end

defmodule InternalApi.User.ListFavoritesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
end

defmodule InternalApi.User.ListFavoritesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:favorites, 1, repeated: true, type: InternalApi.User.Favorite)
end

defmodule InternalApi.User.Favorite do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
  field(:favorite_id, 3, type: :string, json_name: "favoriteId")
  field(:kind, 4, type: InternalApi.User.Favorite.Kind, enum: true)
end

defmodule InternalApi.User.DescribeManyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_ids, 1, repeated: true, type: :string, json_name: "userIds")
end

defmodule InternalApi.User.DescribeManyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:users, 1, repeated: true, type: InternalApi.User.User)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.User.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 2, type: :string, json_name: "userId")
end

defmodule InternalApi.User.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:email, 3, type: :string)
  field(:created_at, 4, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:avatar_url, 5, type: :string, json_name: "avatarUrl")
  field(:user_id, 6, type: :string, json_name: "userId")
  field(:github_token, 7, type: :string, json_name: "githubToken")

  field(:github_scope, 12,
    type: InternalApi.User.DescribeResponse.RepoScope,
    json_name: "githubScope",
    enum: true
  )

  field(:github_uid, 8, type: :string, json_name: "githubUid")
  field(:name, 10, type: :string)
  field(:github_login, 11, type: :string, json_name: "githubLogin")
  field(:company, 13, type: :string)
  field(:blocked_at, 14, type: Google.Protobuf.Timestamp, json_name: "blockedAt")

  field(:repository_scopes, 15,
    type: InternalApi.User.RepositoryScopes,
    json_name: "repositoryScopes"
  )

  field(:repository_providers, 16,
    repeated: true,
    type: InternalApi.User.RepositoryProvider,
    json_name: "repositoryProviders"
  )

  field(:user, 17, type: InternalApi.User.User)
end

defmodule InternalApi.User.RepositoryProvider do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:type, 1, type: InternalApi.User.RepositoryProvider.Type, enum: true)
  field(:scope, 2, type: InternalApi.User.RepositoryProvider.Scope, enum: true)
  field(:login, 3, type: :string)
  field(:uid, 4, type: :string)
end

defmodule InternalApi.User.RepositoryScopes.RepositoryScope do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:scope, 2, type: InternalApi.User.RepositoryScopes.RepositoryScope.Scope, enum: true)
  field(:login, 3, type: :string)
  field(:uid, 4, type: :string)
end

defmodule InternalApi.User.RepositoryScopes do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:github, 1, type: InternalApi.User.RepositoryScopes.RepositoryScope)
  field(:bitbucket, 2, type: InternalApi.User.RepositoryScopes.RepositoryScope)
end

defmodule InternalApi.User.UpdateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user, 1, type: InternalApi.User.User)
end

defmodule InternalApi.User.UpdateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: Google.Rpc.Status)
  field(:user, 2, type: InternalApi.User.User)
end

defmodule InternalApi.User.SearchUsersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:query, 1, type: :string)
  field(:limit, 2, type: :int32)
end

defmodule InternalApi.User.SearchUsersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:users, 1, repeated: true, type: InternalApi.User.User)
end

defmodule InternalApi.User.DeleteWithOwnedOrgsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
end

defmodule InternalApi.User.RegenerateTokenRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
end

defmodule InternalApi.User.RegenerateTokenResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:status, 1, type: Google.Rpc.Status)
  field(:api_token, 3, type: :string, json_name: "apiToken")
end

defmodule InternalApi.User.CheckGithubTokenRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
end

defmodule InternalApi.User.CheckGithubTokenResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:revoked, 1, type: :bool)
  field(:repo, 2, type: :bool)
  field(:public_repo, 3, type: :bool, json_name: "publicRepo")
end

defmodule InternalApi.User.BlockAccountRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
end

defmodule InternalApi.User.UnblockAccountRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
end

defmodule InternalApi.User.GetRepositoryTokenRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")

  field(:integration_type, 2,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    json_name: "integrationType",
    enum: true
  )
end

defmodule InternalApi.User.GetRepositoryTokenResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:token, 1, type: :string)
  field(:expires_at, 2, type: Google.Protobuf.Timestamp, json_name: "expiresAt")
end

defmodule InternalApi.User.DescribeByRepositoryProviderRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:provider, 1, type: InternalApi.User.RepositoryProvider)
end

defmodule InternalApi.User.DescribeByEmailRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:email, 1, type: :string)
end

defmodule InternalApi.User.RefreshRepositoryProviderRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:type, 2, type: InternalApi.User.RepositoryProvider.Type, enum: true)
end

defmodule InternalApi.User.RefreshRepositoryProviderResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")

  field(:repository_provider, 2,
    type: InternalApi.User.RepositoryProvider,
    json_name: "repositoryProvider"
  )
end

defmodule InternalApi.User.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:email, 1, type: :string)
  field(:name, 2, type: :string)
  field(:password, 3, type: :string)

  field(:repository_providers, 4,
    repeated: true,
    type: InternalApi.User.RepositoryProvider,
    json_name: "repositoryProviders"
  )

  field(:skip_password_change, 5, type: :bool, json_name: "skipPasswordChange")
end

defmodule InternalApi.User.User do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:avatar_url, 3, type: :string, json_name: "avatarUrl")
  field(:github_uid, 4, type: :string, json_name: "githubUid")
  field(:name, 5, type: :string)
  field(:github_login, 7, type: :string, json_name: "githubLogin")
  field(:company, 8, type: :string)
  field(:email, 9, type: :string)
  field(:blocked_at, 10, type: Google.Protobuf.Timestamp, json_name: "blockedAt")
  field(:created_at, 11, type: Google.Protobuf.Timestamp, json_name: "createdAt")

  field(:repository_providers, 12,
    repeated: true,
    type: InternalApi.User.RepositoryProvider,
    json_name: "repositoryProviders"
  )

  field(:visited_at, 13, type: Google.Protobuf.Timestamp, json_name: "visitedAt")
  field(:single_org_user, 14, type: :bool, json_name: "singleOrgUser")
  field(:org_id, 15, type: :string, json_name: "orgId")

  field(:creation_source, 16,
    type: InternalApi.User.User.CreationSource,
    json_name: "creationSource",
    enum: true
  )

  field(:deactivated, 17, type: :bool)
end

defmodule InternalApi.User.UserCreated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:invited, 3, type: :bool)
end

defmodule InternalApi.User.UserDeleted do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.UserUpdated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.UserJoinedOrganization do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.UserLeftOrganization do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.MemberInvited do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:github_username, 1, type: :string, json_name: "githubUsername")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.ActiveOwner do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.InactiveOwner do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.WorkEmailAdded do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:old_email, 3, type: :string, json_name: "oldEmail")
  field(:new_email, 4, type: :string, json_name: "newEmail")
end

defmodule InternalApi.User.FavoriteCreated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:favorite, 1, type: InternalApi.User.Favorite)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.FavoriteDeleted do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:favorite, 1, type: InternalApi.User.Favorite)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.UserService.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.User.UserService", protoc_gen_elixir_version: "0.13.0"

  rpc(:Describe, InternalApi.User.DescribeRequest, InternalApi.User.DescribeResponse)

  rpc(
    :DescribeByRepositoryProvider,
    InternalApi.User.DescribeByRepositoryProviderRequest,
    InternalApi.User.User
  )

  rpc(:DescribeByEmail, InternalApi.User.DescribeByEmailRequest, InternalApi.User.User)

  rpc(:SearchUsers, InternalApi.User.SearchUsersRequest, InternalApi.User.SearchUsersResponse)

  rpc(:DescribeMany, InternalApi.User.DescribeManyRequest, InternalApi.User.DescribeManyResponse)

  rpc(:Update, InternalApi.User.UpdateRequest, InternalApi.User.UpdateResponse)

  rpc(:DeleteWithOwnedOrgs, InternalApi.User.DeleteWithOwnedOrgsRequest, InternalApi.User.User)

  rpc(
    :RegenerateToken,
    InternalApi.User.RegenerateTokenRequest,
    InternalApi.User.RegenerateTokenResponse
  )

  rpc(
    :ListFavorites,
    InternalApi.User.ListFavoritesRequest,
    InternalApi.User.ListFavoritesResponse
  )

  rpc(:CreateFavorite, InternalApi.User.Favorite, InternalApi.User.Favorite)

  rpc(:DeleteFavorite, InternalApi.User.Favorite, InternalApi.User.Favorite)

  rpc(
    :CheckGithubToken,
    InternalApi.User.CheckGithubTokenRequest,
    InternalApi.User.CheckGithubTokenResponse
  )

  rpc(:BlockAccount, InternalApi.User.BlockAccountRequest, InternalApi.User.User)

  rpc(:UnblockAccount, InternalApi.User.UnblockAccountRequest, InternalApi.User.User)

  rpc(
    :GetRepositoryToken,
    InternalApi.User.GetRepositoryTokenRequest,
    InternalApi.User.GetRepositoryTokenResponse
  )

  rpc(
    :RefreshRepositoryProvider,
    InternalApi.User.RefreshRepositoryProviderRequest,
    InternalApi.User.RefreshRepositoryProviderResponse
  )

  rpc(:Create, InternalApi.User.CreateRequest, InternalApi.User.User)
end

defmodule InternalApi.User.UserService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.User.UserService.Service
end
