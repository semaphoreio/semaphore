defmodule InternalApi.User.ListFavoritesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          organization_id: String.t()
        }
  defstruct [:user_id, :organization_id]

  field(:user_id, 1, type: :string)
  field(:organization_id, 2, type: :string)
end

defmodule InternalApi.User.ListFavoritesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          favorites: [InternalApi.User.Favorite.t()]
        }
  defstruct [:favorites]

  field(:favorites, 1, repeated: true, type: InternalApi.User.Favorite)
end

defmodule InternalApi.User.Favorite do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          organization_id: String.t(),
          favorite_id: String.t(),
          kind: integer
        }
  defstruct [:user_id, :organization_id, :favorite_id, :kind]

  field(:user_id, 1, type: :string)
  field(:organization_id, 2, type: :string)
  field(:favorite_id, 3, type: :string)
  field(:kind, 4, type: InternalApi.User.Favorite.Kind, enum: true)
end

defmodule InternalApi.User.Favorite.Kind do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PROJECT, 0)
  field(:DASHBOARD, 1)
end

defmodule InternalApi.User.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_ids: [String.t()]
        }
  defstruct [:user_ids]

  field(:user_ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.User.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          users: [InternalApi.User.User.t()],
          status: InternalApi.ResponseStatus.t()
        }
  defstruct [:users, :status]

  field(:users, 1, repeated: true, type: InternalApi.User.User)
  field(:status, 2, type: InternalApi.ResponseStatus)
end

defmodule InternalApi.User.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t()
        }
  defstruct [:user_id]

  field(:user_id, 2, type: :string)
end

defmodule InternalApi.User.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          email: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          avatar_url: String.t(),
          user_id: String.t(),
          github_token: String.t(),
          github_scope: integer,
          github_uid: String.t(),
          name: String.t(),
          github_login: String.t(),
          company: String.t(),
          blocked_at: Google.Protobuf.Timestamp.t(),
          repository_scopes: InternalApi.User.RepositoryScopes.t(),
          repository_providers: [InternalApi.User.RepositoryProvider.t()],
          user: InternalApi.User.User.t()
        }
  defstruct [
    :status,
    :email,
    :created_at,
    :avatar_url,
    :user_id,
    :github_token,
    :github_scope,
    :github_uid,
    :name,
    :github_login,
    :company,
    :blocked_at,
    :repository_scopes,
    :repository_providers,
    :user
  ]

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:email, 3, type: :string)
  field(:created_at, 4, type: Google.Protobuf.Timestamp)
  field(:avatar_url, 5, type: :string)
  field(:user_id, 6, type: :string)
  field(:github_token, 7, type: :string)
  field(:github_scope, 12, type: InternalApi.User.DescribeResponse.RepoScope, enum: true)
  field(:github_uid, 8, type: :string)
  field(:name, 10, type: :string)
  field(:github_login, 11, type: :string)
  field(:company, 13, type: :string)
  field(:blocked_at, 14, type: Google.Protobuf.Timestamp)
  field(:repository_scopes, 15, type: InternalApi.User.RepositoryScopes)
  field(:repository_providers, 16, repeated: true, type: InternalApi.User.RepositoryProvider)
  field(:user, 17, type: InternalApi.User.User)
end

defmodule InternalApi.User.DescribeResponse.RepoScope do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NONE, 0)
  field(:PUBLIC, 1)
  field(:PRIVATE, 2)
end

defmodule InternalApi.User.RepositoryProvider do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: integer,
          scope: integer,
          login: String.t(),
          uid: String.t()
        }
  defstruct [:type, :scope, :login, :uid]

  field(:type, 1, type: InternalApi.User.RepositoryProvider.Type, enum: true)
  field(:scope, 2, type: InternalApi.User.RepositoryProvider.Scope, enum: true)
  field(:login, 3, type: :string)
  field(:uid, 4, type: :string)
end

defmodule InternalApi.User.RepositoryProvider.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:GITHUB, 0)
  field(:BITBUCKET, 1)
  field(:GITLAB, 2)
end

defmodule InternalApi.User.RepositoryProvider.Scope do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NONE, 0)
  field(:EMAIL, 1)
  field(:PUBLIC, 2)
  field(:PRIVATE, 3)
end

defmodule InternalApi.User.RepositoryScopes do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          github: InternalApi.User.RepositoryScopes.RepositoryScope.t(),
          bitbucket: InternalApi.User.RepositoryScopes.RepositoryScope.t()
        }
  defstruct [:github, :bitbucket]

  field(:github, 1, type: InternalApi.User.RepositoryScopes.RepositoryScope)
  field(:bitbucket, 2, type: InternalApi.User.RepositoryScopes.RepositoryScope)
end

defmodule InternalApi.User.RepositoryScopes.RepositoryScope do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          scope: integer,
          login: String.t(),
          uid: String.t()
        }
  defstruct [:scope, :login, :uid]

  field(:scope, 2, type: InternalApi.User.RepositoryScopes.RepositoryScope.Scope, enum: true)
  field(:login, 3, type: :string)
  field(:uid, 4, type: :string)
end

defmodule InternalApi.User.RepositoryScopes.RepositoryScope.Scope do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NONE, 0)
  field(:EMAIL, 1)
  field(:PUBLIC, 2)
  field(:PRIVATE, 3)
end

defmodule InternalApi.User.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user: InternalApi.User.User.t()
        }
  defstruct [:user]

  field(:user, 1, type: InternalApi.User.User)
end

defmodule InternalApi.User.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          user: InternalApi.User.User.t()
        }
  defstruct [:status, :user]

  field(:status, 1, type: Google.Rpc.Status)
  field(:user, 2, type: InternalApi.User.User)
end

defmodule InternalApi.User.SearchUsersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          query: String.t(),
          limit: integer
        }
  defstruct [:query, :limit]

  field(:query, 1, type: :string)
  field(:limit, 2, type: :int32)
end

defmodule InternalApi.User.SearchUsersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          users: [InternalApi.User.User.t()]
        }
  defstruct [:users]

  field(:users, 1, repeated: true, type: InternalApi.User.User)
end

defmodule InternalApi.User.DeleteWithOwnedOrgsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t()
        }
  defstruct [:user_id]

  field(:user_id, 1, type: :string)
end

defmodule InternalApi.User.RegenerateTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t()
        }
  defstruct [:user_id]

  field(:user_id, 1, type: :string)
end

defmodule InternalApi.User.RegenerateTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          api_token: String.t()
        }
  defstruct [:status, :api_token]

  field(:status, 1, type: Google.Rpc.Status)
  field(:api_token, 3, type: :string)
end

defmodule InternalApi.User.CheckGithubTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t()
        }
  defstruct [:user_id]

  field(:user_id, 1, type: :string)
end

defmodule InternalApi.User.CheckGithubTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          revoked: boolean,
          repo: boolean,
          public_repo: boolean
        }
  defstruct [:revoked, :repo, :public_repo]

  field(:revoked, 1, type: :bool)
  field(:repo, 2, type: :bool)
  field(:public_repo, 3, type: :bool)
end

defmodule InternalApi.User.BlockAccountRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t()
        }
  defstruct [:user_id]

  field(:user_id, 1, type: :string)
end

defmodule InternalApi.User.UnblockAccountRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t()
        }
  defstruct [:user_id]

  field(:user_id, 1, type: :string)
end

defmodule InternalApi.User.GetRepositoryTokenRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          integration_type: integer
        }
  defstruct [:user_id, :integration_type]

  field(:user_id, 1, type: :string)
  field(:integration_type, 2, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true)
end

defmodule InternalApi.User.GetRepositoryTokenResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          token: String.t(),
          expires_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:token, :expires_at]

  field(:token, 1, type: :string)
  field(:expires_at, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.DescribeByRepositoryProviderRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          provider: InternalApi.User.RepositoryProvider.t()
        }
  defstruct [:provider]

  field(:provider, 1, type: InternalApi.User.RepositoryProvider)
end

defmodule InternalApi.User.DescribeByEmailRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          email: String.t()
        }
  defstruct [:email]

  field(:email, 1, type: :string)
end

defmodule InternalApi.User.DescribeByEmailRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          email: String.t()
        }
  defstruct [:email]

  field :email, 1, type: :string
end

defmodule InternalApi.User.RefreshRepositoryProviderRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          type: integer
        }
  defstruct [:user_id, :type]

  field(:user_id, 1, type: :string)
  field(:type, 2, type: InternalApi.User.RepositoryProvider.Type, enum: true)
end

defmodule InternalApi.User.RefreshRepositoryProviderResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          repository_provider: InternalApi.User.RepositoryProvider.t()
        }
  defstruct [:user_id, :repository_provider]

  field(:user_id, 1, type: :string)
  field(:repository_provider, 2, type: InternalApi.User.RepositoryProvider)
end

defmodule InternalApi.User.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          email: String.t(),
          name: String.t(),
          password: String.t(),
          repository_providers: [InternalApi.User.RepositoryProvider.t()],
          skip_password_change: boolean
        }
  defstruct [:email, :name, :password, :repository_providers, :skip_password_change]

  field(:email, 1, type: :string)
  field(:name, 2, type: :string)
  field(:password, 3, type: :string)
  field(:repository_providers, 4, repeated: true, type: InternalApi.User.RepositoryProvider)
  field(:skip_password_change, 5, type: :bool)
end

defmodule InternalApi.User.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          email: String.t(),
          name: String.t(),
          password: String.t(),
          repository_providers: [InternalApi.User.RepositoryProvider.t()],
          skip_password_change: boolean
        }
  defstruct [:email, :name, :password, :repository_providers, :skip_password_change]

  field :email, 1, type: :string
  field :name, 2, type: :string
  field :password, 3, type: :string
  field :repository_providers, 4, repeated: true, type: InternalApi.User.RepositoryProvider
  field :skip_password_change, 5, type: :bool
end

defmodule InternalApi.User.User do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          avatar_url: String.t(),
          github_uid: String.t(),
          name: String.t(),
          github_login: String.t(),
          company: String.t(),
          email: String.t(),
          blocked_at: Google.Protobuf.Timestamp.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          repository_providers: [InternalApi.User.RepositoryProvider.t()],
          visited_at: Google.Protobuf.Timestamp.t(),
          single_org_user: boolean,
          org_id: String.t(),
          creation_source: integer,
          deactivated: boolean
        }
  defstruct [
    :id,
    :avatar_url,
    :github_uid,
    :name,
    :github_login,
    :company,
    :email,
    :blocked_at,
    :created_at,
    :repository_providers,
    :visited_at,
    :single_org_user,
    :org_id,
    :creation_source,
    :deactivated
  ]

  field(:id, 1, type: :string)
  field(:avatar_url, 3, type: :string)
  field(:github_uid, 4, type: :string)
  field(:name, 5, type: :string)
  field(:github_login, 7, type: :string)
  field(:company, 8, type: :string)
  field(:email, 9, type: :string)
  field(:blocked_at, 10, type: Google.Protobuf.Timestamp)
  field(:created_at, 11, type: Google.Protobuf.Timestamp)
  field(:repository_providers, 12, repeated: true, type: InternalApi.User.RepositoryProvider)
  field(:visited_at, 13, type: Google.Protobuf.Timestamp)
  field(:single_org_user, 14, type: :bool)
  field(:org_id, 15, type: :string)
  field(:creation_source, 16, type: InternalApi.User.User.CreationSource, enum: true)
  field(:deactivated, 17, type: :bool)
end

defmodule InternalApi.User.User.CreationSource do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NOT_SET, 0)
  field(:OKTA, 1)
end

defmodule InternalApi.User.UserCreated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          invited: boolean
        }
  defstruct [:user_id, :timestamp, :invited]

  field(:user_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:invited, 3, type: :bool)
end

defmodule InternalApi.User.UserDeleted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:user_id, :timestamp]

  field(:user_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.UserUpdated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:user_id, :timestamp]

  field(:user_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.UserJoinedOrganization do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:user_id, :org_id, :timestamp]

  field(:user_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.UserLeftOrganization do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:user_id, :org_id, :timestamp]

  field(:user_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.MemberInvited do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          github_username: String.t(),
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:github_username, :org_id, :timestamp]

  field(:github_username, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.ActiveOwner do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:user_id, :timestamp]

  field(:user_id, 1, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.InactiveOwner do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:user_id, :timestamp]

  field(:user_id, 1, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.WorkEmailAdded do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          old_email: String.t(),
          new_email: String.t()
        }
  defstruct [:user_id, :timestamp, :old_email, :new_email]

  field(:user_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:old_email, 3, type: :string)
  field(:new_email, 4, type: :string)
end

defmodule InternalApi.User.FavoriteCreated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          favorite: InternalApi.User.Favorite.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:favorite, :timestamp]

  field(:favorite, 1, type: InternalApi.User.Favorite)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.FavoriteDeleted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          favorite: InternalApi.User.Favorite.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:favorite, :timestamp]

  field(:favorite, 1, type: InternalApi.User.Favorite)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.User.UserService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.User.UserService"

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
