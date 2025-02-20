defmodule InternalApi.Organization.ListRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t :: integer | :BY_NAME_ASC | :BY_CREATION_TIME_ASC

  field :BY_NAME_ASC, 0
  field :BY_CREATION_TIME_ASC, 1
end

defmodule InternalApi.Organization.Suspension.Reason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t :: integer | :INSUFFICIENT_FUNDS | :ACCOUNT_AT_RISK | :VIOLATION_OF_TOS

  field :INSUFFICIENT_FUNDS, 0
  field :ACCOUNT_AT_RISK, 1
  field :VIOLATION_OF_TOS, 2
end

defmodule InternalApi.Organization.Member.Role do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t :: integer | :MEMBER | :OWNER | :ADMIN

  field :MEMBER, 0
  field :OWNER, 1
  field :ADMIN, 2
end

defmodule InternalApi.Organization.Quota.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t ::
          integer
          | :MAX_PEOPLE_IN_ORG
          | :MAX_PARALELLISM_IN_ORG
          | :MAX_PROJECTS_IN_ORG
          | :MAX_PARALLEL_E1_STANDARD_2
          | :MAX_PARALLEL_E1_STANDARD_4
          | :MAX_PARALLEL_E1_STANDARD_8
          | :MAX_PARALLEL_A1_STANDARD_4
          | :MAX_PARALLEL_A1_STANDARD_8

  field :MAX_PEOPLE_IN_ORG, 0
  field :MAX_PARALELLISM_IN_ORG, 1
  field :MAX_PROJECTS_IN_ORG, 7
  field :MAX_PARALLEL_E1_STANDARD_2, 2
  field :MAX_PARALLEL_E1_STANDARD_4, 3
  field :MAX_PARALLEL_E1_STANDARD_8, 4
  field :MAX_PARALLEL_A1_STANDARD_4, 5
  field :MAX_PARALLEL_A1_STANDARD_8, 6
end

defmodule InternalApi.Organization.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_username: String.t(),
          include_quotas: boolean
        }

  defstruct org_id: "",
            org_username: "",
            include_quotas: false

  field :org_id, 1, type: :string, json_name: "orgId"
  field :org_username, 2, type: :string, json_name: "orgUsername"
  field :include_quotas, 3, type: :bool, json_name: "includeQuotas"
end

defmodule InternalApi.Organization.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil,
          organization: InternalApi.Organization.Organization.t() | nil
        }

  defstruct status: nil,
            organization: nil

  field :status, 1, type: InternalApi.ResponseStatus
  field :organization, 2, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          created_at_gt: Google.Protobuf.Timestamp.t() | nil,
          order: InternalApi.Organization.ListRequest.Order.t(),
          page_size: integer,
          page_token: String.t()
        }

  defstruct user_id: "",
            created_at_gt: nil,
            order: :BY_NAME_ASC,
            page_size: 0,
            page_token: ""

  field :user_id, 2, type: :string, json_name: "userId"
  field :created_at_gt, 3, type: Google.Protobuf.Timestamp, json_name: "createdAtGt"
  field :order, 4, type: InternalApi.Organization.ListRequest.Order, enum: true
  field :page_size, 5, type: :int32, json_name: "pageSize"
  field :page_token, 6, type: :string, json_name: "pageToken"
end

defmodule InternalApi.Organization.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil,
          organizations: [InternalApi.Organization.Organization.t()],
          next_page_token: String.t()
        }

  defstruct status: nil,
            organizations: [],
            next_page_token: ""

  field :status, 1, type: InternalApi.ResponseStatus
  field :organizations, 2, repeated: true, type: InternalApi.Organization.Organization
  field :next_page_token, 3, type: :string, json_name: "nextPageToken"
end

defmodule InternalApi.Organization.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          creator_id: String.t(),
          organization_name: String.t(),
          organization_username: String.t()
        }

  defstruct creator_id: "",
            organization_name: "",
            organization_username: ""

  field :creator_id, 1, type: :string, json_name: "creatorId"
  field :organization_name, 2, type: :string, json_name: "organizationName"
  field :organization_username, 3, type: :string, json_name: "organizationUsername"
end

defmodule InternalApi.Organization.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil,
          organization: InternalApi.Organization.Organization.t() | nil
        }

  defstruct status: nil,
            organization: nil

  field :status, 1, type: InternalApi.ResponseStatus
  field :organization, 2, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.CreateWithQuotasRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization: InternalApi.Organization.Organization.t() | nil,
          quotas: [InternalApi.Organization.Quota.t()]
        }

  defstruct organization: nil,
            quotas: []

  field :organization, 1, type: InternalApi.Organization.Organization
  field :quotas, 2, repeated: true, type: InternalApi.Organization.Quota
end

defmodule InternalApi.Organization.CreateWithQuotasResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization: InternalApi.Organization.Organization.t() | nil
        }

  defstruct organization: nil

  field :organization, 1, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization: InternalApi.Organization.Organization.t() | nil
        }

  defstruct organization: nil

  field :organization, 1, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t() | nil,
          organization: InternalApi.Organization.Organization.t() | nil
        }

  defstruct status: nil,
            organization: nil

  field :status, 1, type: Google.Rpc.Status
  field :organization, 2, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.IsValidResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          is_valid: boolean,
          errors: String.t()
        }

  defstruct is_valid: false,
            errors: ""

  field :is_valid, 1, type: :bool, json_name: "isValid"
  field :errors, 2, type: :string
end

defmodule InternalApi.Organization.IsMemberRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t(),
          org_username: String.t()
        }

  defstruct user_id: "",
            org_id: "",
            org_username: ""

  field :user_id, 1, type: :string, json_name: "userId"
  field :org_id, 3, type: :string, json_name: "orgId"
  field :org_username, 4, type: :string, json_name: "orgUsername"
end

defmodule InternalApi.Organization.IsMemberResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil,
          is_member: boolean
        }

  defstruct status: nil,
            is_member: false

  field :status, 1, type: InternalApi.ResponseStatus
  field :is_member, 2, type: :bool, json_name: "isMember"
end

defmodule InternalApi.Organization.IsOwnerRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t()
        }

  defstruct user_id: "",
            org_id: ""

  field :user_id, 1, type: :string, json_name: "userId"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.IsOwnerResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil,
          is_owner: boolean
        }

  defstruct status: nil,
            is_owner: false

  field :status, 1, type: InternalApi.ResponseStatus
  field :is_owner, 2, type: :bool, json_name: "isOwner"
end

defmodule InternalApi.Organization.MakeOwnerRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          owner_id: String.t()
        }

  defstruct org_id: "",
            owner_id: ""

  field :org_id, 1, type: :string, json_name: "orgId"
  field :owner_id, 2, type: :string, json_name: "ownerId"
end

defmodule InternalApi.Organization.MembersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_username: String.t(),
          only_members: boolean,
          name_contains: String.t()
        }

  defstruct org_id: "",
            org_username: "",
            only_members: false,
            name_contains: ""

  field :org_id, 1, type: :string, json_name: "orgId"
  field :org_username, 2, type: :string, json_name: "orgUsername"
  field :only_members, 3, type: :bool, json_name: "onlyMembers"
  field :name_contains, 4, type: :string, json_name: "nameContains"
end

defmodule InternalApi.Organization.MembersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t() | nil,
          members: [InternalApi.Organization.Member.t()],
          not_logged_in_members: [InternalApi.Organization.Member.t()]
        }

  defstruct status: nil,
            members: [],
            not_logged_in_members: []

  field :status, 1, type: InternalApi.ResponseStatus
  field :members, 2, repeated: true, type: InternalApi.Organization.Member

  field :not_logged_in_members, 3,
    repeated: true,
    type: InternalApi.Organization.Member,
    json_name: "notLoggedInMembers"
end

defmodule InternalApi.Organization.AddMemberRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          creator_id: String.t(),
          username: String.t()
        }

  defstruct org_id: "",
            creator_id: "",
            username: ""

  field :org_id, 1, type: :string, json_name: "orgId"
  field :creator_id, 2, type: :string, json_name: "creatorId"
  field :username, 3, type: :string
end

defmodule InternalApi.Organization.AddMemberResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t() | nil,
          member: InternalApi.Organization.Member.t() | nil
        }

  defstruct status: nil,
            member: nil

  field :status, 1, type: Google.Rpc.Status
  field :member, 2, type: InternalApi.Organization.Member
end

defmodule InternalApi.Organization.AddMembersRequest.MemberData do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          github_username: String.t(),
          github_uid: String.t(),
          invite_email: String.t()
        }

  defstruct github_username: "",
            github_uid: "",
            invite_email: ""

  field :github_username, 1, type: :string, json_name: "githubUsername"
  field :github_uid, 2, type: :string, json_name: "githubUid"
  field :invite_email, 3, type: :string, json_name: "inviteEmail"
end

defmodule InternalApi.Organization.AddMembersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          creator_id: String.t(),
          members_data: [InternalApi.Organization.AddMembersRequest.MemberData.t()]
        }

  defstruct org_id: "",
            creator_id: "",
            members_data: []

  field :org_id, 1, type: :string, json_name: "orgId"
  field :creator_id, 2, type: :string, json_name: "creatorId"

  field :members_data, 3,
    repeated: true,
    type: InternalApi.Organization.AddMembersRequest.MemberData,
    json_name: "membersData"
end

defmodule InternalApi.Organization.AddMembersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          members: [InternalApi.Organization.Member.t()]
        }

  defstruct members: []

  field :members, 1, repeated: true, type: InternalApi.Organization.Member
end

defmodule InternalApi.Organization.DeleteMemberRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          membership_id: String.t(),
          user_id: String.t()
        }

  defstruct org_id: "",
            membership_id: "",
            user_id: ""

  field :org_id, 1, type: :string, json_name: "orgId"
  field :membership_id, 3, type: :string, json_name: "membershipId"
  field :user_id, 4, type: :string, json_name: "userId"
end

defmodule InternalApi.Organization.DeleteMemberResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t() | nil
        }

  defstruct status: nil

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.SuspendRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          origin: String.t(),
          description: String.t(),
          reason: InternalApi.Organization.Suspension.Reason.t()
        }

  defstruct org_id: "",
            origin: "",
            description: "",
            reason: :INSUFFICIENT_FUNDS

  field :org_id, 1, type: :string, json_name: "orgId"
  field :origin, 2, type: :string
  field :description, 3, type: :string
  field :reason, 4, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.SuspendResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t() | nil
        }

  defstruct status: nil

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.SetOpenSourceRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct org_id: ""

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.SetOpenSourceResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization: InternalApi.Organization.Organization.t() | nil
        }

  defstruct organization: nil

  field :organization, 1, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UnsuspendRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          origin: String.t(),
          description: String.t(),
          reason: InternalApi.Organization.Suspension.Reason.t()
        }

  defstruct org_id: "",
            origin: "",
            description: "",
            reason: :INSUFFICIENT_FUNDS

  field :org_id, 1, type: :string, json_name: "orgId"
  field :origin, 3, type: :string
  field :description, 2, type: :string
  field :reason, 4, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.UnsuspendResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t() | nil
        }

  defstruct status: nil

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.VerifyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct org_id: ""

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.ListSuspensionsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct org_id: ""

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.ListSuspensionsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t() | nil,
          suspensions: [InternalApi.Organization.Suspension.t()]
        }

  defstruct status: nil,
            suspensions: []

  field :status, 1, type: Google.Rpc.Status
  field :suspensions, 2, repeated: true, type: InternalApi.Organization.Suspension
end

defmodule InternalApi.Organization.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct org_id: ""

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.Organization do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_username: String.t(),
          created_at: Google.Protobuf.Timestamp.t() | nil,
          avatar_url: String.t(),
          org_id: String.t(),
          name: String.t(),
          owner_id: String.t(),
          suspended: boolean,
          open_source: boolean,
          verified: boolean,
          restricted: boolean,
          ip_allow_list: [String.t()],
          quotas: [InternalApi.Organization.Quota.t()]
        }

  defstruct org_username: "",
            created_at: nil,
            avatar_url: "",
            org_id: "",
            name: "",
            owner_id: "",
            suspended: false,
            open_source: false,
            verified: false,
            restricted: false,
            ip_allow_list: [],
            quotas: []

  field :org_username, 1, type: :string, json_name: "orgUsername"
  field :created_at, 2, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :avatar_url, 3, type: :string, json_name: "avatarUrl"
  field :org_id, 4, type: :string, json_name: "orgId"
  field :name, 5, type: :string
  field :owner_id, 6, type: :string, json_name: "ownerId"
  field :suspended, 7, type: :bool
  field :open_source, 9, type: :bool, json_name: "openSource"
  field :verified, 10, type: :bool
  field :restricted, 11, type: :bool
  field :ip_allow_list, 12, repeated: true, type: :string, json_name: "ipAllowList"
  field :quotas, 8, repeated: true, type: InternalApi.Organization.Quota
end

defmodule InternalApi.Organization.Suspension do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          origin: String.t(),
          description: String.t(),
          reason: InternalApi.Organization.Suspension.Reason.t(),
          created_at: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct origin: "",
            description: "",
            reason: :INSUFFICIENT_FUNDS,
            created_at: nil

  field :origin, 1, type: :string
  field :description, 2, type: :string
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
  field :created_at, 4, type: Google.Protobuf.Timestamp, json_name: "createdAt"
end

defmodule InternalApi.Organization.Member do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          screen_name: String.t(),
          avatar_url: String.t(),
          user_id: String.t(),
          role: InternalApi.Organization.Member.Role.t(),
          invited_at: Google.Protobuf.Timestamp.t() | nil,
          membership_id: String.t(),
          github_username: String.t(),
          github_uid: String.t()
        }

  defstruct screen_name: "",
            avatar_url: "",
            user_id: "",
            role: :MEMBER,
            invited_at: nil,
            membership_id: "",
            github_username: "",
            github_uid: ""

  field :screen_name, 1, type: :string, json_name: "screenName"
  field :avatar_url, 2, type: :string, json_name: "avatarUrl"
  field :user_id, 3, type: :string, json_name: "userId"
  field :role, 4, type: InternalApi.Organization.Member.Role, enum: true
  field :invited_at, 5, type: Google.Protobuf.Timestamp, json_name: "invitedAt"
  field :membership_id, 6, type: :string, json_name: "membershipId"
  field :github_username, 7, type: :string, json_name: "githubUsername"
  field :github_uid, 8, type: :string, json_name: "githubUid"
end

defmodule InternalApi.Organization.Quota do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          type: InternalApi.Organization.Quota.Type.t(),
          value: non_neg_integer
        }

  defstruct type: :MAX_PEOPLE_IN_ORG,
            value: 0

  field :type, 1, type: InternalApi.Organization.Quota.Type, enum: true
  field :value, 2, type: :uint32
end

defmodule InternalApi.Organization.GetQuotasRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          types: [InternalApi.Organization.Quota.Type.t()]
        }

  defstruct org_id: "",
            types: []

  field :org_id, 1, type: :string, json_name: "orgId"
  field :types, 2, repeated: true, type: InternalApi.Organization.Quota.Type, enum: true
end

defmodule InternalApi.Organization.GetQuotaResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          quotas: [InternalApi.Organization.Quota.t()]
        }

  defstruct quotas: []

  field :quotas, 1, repeated: true, type: InternalApi.Organization.Quota
end

defmodule InternalApi.Organization.UpdateQuotasRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          quotas: [InternalApi.Organization.Quota.t()]
        }

  defstruct org_id: "",
            quotas: []

  field :org_id, 1, type: :string, json_name: "orgId"
  field :quotas, 2, repeated: true, type: InternalApi.Organization.Quota
end

defmodule InternalApi.Organization.UpdateQuotasResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          quotas: [InternalApi.Organization.Quota.t()]
        }

  defstruct quotas: []

  field :quotas, 1, repeated: true, type: InternalApi.Organization.Quota
end

defmodule InternalApi.Organization.RepositoryIntegratorsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct org_id: ""

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.RepositoryIntegratorsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          primary: InternalApi.RepositoryIntegrator.IntegrationType.t(),
          enabled: [InternalApi.RepositoryIntegrator.IntegrationType.t()],
          available: [InternalApi.RepositoryIntegrator.IntegrationType.t()]
        }

  defstruct primary: :GITHUB_OAUTH_TOKEN,
            enabled: [],
            available: []

  field :primary, 1, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true

  field :enabled, 2,
    repeated: true,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    enum: true

  field :available, 3,
    repeated: true,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    enum: true
end

defmodule InternalApi.Organization.OrganizationCreated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct org_id: "",
            timestamp: nil

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationDeleted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct org_id: "",
            timestamp: nil

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationUpdated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct org_id: "",
            timestamp: nil

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationBlocked do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil,
          reason: InternalApi.Organization.Suspension.Reason.t()
        }

  defstruct org_id: "",
            timestamp: nil,
            reason: :INSUFFICIENT_FUNDS

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationSuspensionCreated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil,
          reason: InternalApi.Organization.Suspension.Reason.t()
        }

  defstruct org_id: "",
            timestamp: nil,
            reason: :INSUFFICIENT_FUNDS

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationSuspensionRemoved do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil,
          reason: InternalApi.Organization.Suspension.Reason.t()
        }

  defstruct org_id: "",
            timestamp: nil,
            reason: :INSUFFICIENT_FUNDS

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationUnblocked do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct org_id: "",
            timestamp: nil

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationDailyUpdate do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_username: String.t(),
          org_name: String.t(),
          created_at: Google.Protobuf.Timestamp.t() | nil,
          projects_count: integer,
          member_count: integer,
          invited_count: integer,
          owner_id: String.t(),
          owner_email: String.t(),
          owner_owned_orgs_count: integer,
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct org_id: "",
            org_username: "",
            org_name: "",
            created_at: nil,
            projects_count: 0,
            member_count: 0,
            invited_count: 0,
            owner_id: "",
            owner_email: "",
            owner_owned_orgs_count: 0,
            timestamp: nil

  field :org_id, 1, type: :string, json_name: "orgId"
  field :org_username, 2, type: :string, json_name: "orgUsername"
  field :org_name, 3, type: :string, json_name: "orgName"
  field :created_at, 4, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :projects_count, 5, type: :int32, json_name: "projectsCount"
  field :member_count, 6, type: :int32, json_name: "memberCount"
  field :invited_count, 7, type: :int32, json_name: "invitedCount"
  field :owner_id, 8, type: :string, json_name: "ownerId"
  field :owner_email, 9, type: :string, json_name: "ownerEmail"
  field :owner_owned_orgs_count, 10, type: :int32, json_name: "ownerOwnedOrgsCount"
  field :timestamp, 11, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Organization.OrganizationService"

  rpc :Describe,
      InternalApi.Organization.DescribeRequest,
      InternalApi.Organization.DescribeResponse

  rpc :List, InternalApi.Organization.ListRequest, InternalApi.Organization.ListResponse

  rpc :Create, InternalApi.Organization.CreateRequest, InternalApi.Organization.CreateResponse

  rpc :CreateWithQuotas,
      InternalApi.Organization.CreateWithQuotasRequest,
      InternalApi.Organization.CreateWithQuotasResponse

  rpc :Update, InternalApi.Organization.UpdateRequest, InternalApi.Organization.UpdateResponse

  rpc :IsValid, InternalApi.Organization.Organization, InternalApi.Organization.IsValidResponse

  rpc :IsMember,
      InternalApi.Organization.IsMemberRequest,
      InternalApi.Organization.IsMemberResponse

  rpc :IsOwner, InternalApi.Organization.IsOwnerRequest, InternalApi.Organization.IsOwnerResponse

  rpc :MakeOwner, InternalApi.Organization.MakeOwnerRequest, Google.Protobuf.Empty

  rpc :Members, InternalApi.Organization.MembersRequest, InternalApi.Organization.MembersResponse

  rpc :AddMember,
      InternalApi.Organization.AddMemberRequest,
      InternalApi.Organization.AddMemberResponse

  rpc :AddMembers,
      InternalApi.Organization.AddMembersRequest,
      InternalApi.Organization.AddMembersResponse

  rpc :DeleteMember,
      InternalApi.Organization.DeleteMemberRequest,
      InternalApi.Organization.DeleteMemberResponse

  rpc :Suspend, InternalApi.Organization.SuspendRequest, InternalApi.Organization.SuspendResponse

  rpc :Unsuspend,
      InternalApi.Organization.UnsuspendRequest,
      InternalApi.Organization.UnsuspendResponse

  rpc :Verify, InternalApi.Organization.VerifyRequest, InternalApi.Organization.Organization

  rpc :SetOpenSource,
      InternalApi.Organization.SetOpenSourceRequest,
      InternalApi.Organization.SetOpenSourceResponse

  rpc :ListSuspensions,
      InternalApi.Organization.ListSuspensionsRequest,
      InternalApi.Organization.ListSuspensionsResponse

  rpc :UpdateQuotas,
      InternalApi.Organization.UpdateQuotasRequest,
      InternalApi.Organization.UpdateQuotasResponse

  rpc :GetQuotas,
      InternalApi.Organization.GetQuotasRequest,
      InternalApi.Organization.GetQuotaResponse

  rpc :Destroy, InternalApi.Organization.DestroyRequest, Google.Protobuf.Empty

  rpc :RepositoryIntegrators,
      InternalApi.Organization.RepositoryIntegratorsRequest,
      InternalApi.Organization.RepositoryIntegratorsResponse
end

defmodule InternalApi.Organization.OrganizationService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Organization.OrganizationService.Service
end
