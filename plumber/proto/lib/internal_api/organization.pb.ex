defmodule InternalApi.Organization.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_username: String.t(),
          include_quotas: boolean,
          soft_deleted: boolean
        }
  defstruct [:org_id, :org_username, :include_quotas, :soft_deleted]

  field :org_id, 1, type: :string
  field :org_username, 2, type: :string
  field :include_quotas, 3, type: :bool
  field :soft_deleted, 4, type: :bool
end

defmodule InternalApi.Organization.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          organization: InternalApi.Organization.Organization.t()
        }
  defstruct [:status, :organization]

  field :status, 1, type: InternalApi.ResponseStatus
  field :organization, 2, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_ids: [String.t()],
          soft_deleted: boolean
        }
  defstruct [:org_ids, :soft_deleted]

  field :org_ids, 1, repeated: true, type: :string
  field :soft_deleted, 2, type: :bool
end

defmodule InternalApi.Organization.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organizations: [InternalApi.Organization.Organization.t()]
        }
  defstruct [:organizations]

  field :organizations, 1, repeated: true, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          created_at_gt: Google.Protobuf.Timestamp.t(),
          order: integer,
          page_size: integer,
          page_token: String.t(),
          soft_deleted: boolean
        }
  defstruct [:user_id, :created_at_gt, :order, :page_size, :page_token, :soft_deleted]

  field :user_id, 2, type: :string
  field :created_at_gt, 3, type: Google.Protobuf.Timestamp
  field :order, 4, type: InternalApi.Organization.ListRequest.Order, enum: true
  field :page_size, 5, type: :int32
  field :page_token, 6, type: :string
  field :soft_deleted, 7, type: :bool
end

defmodule InternalApi.Organization.ListRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :BY_NAME_ASC, 0
  field :BY_CREATION_TIME_ASC, 1
end

defmodule InternalApi.Organization.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          organizations: [InternalApi.Organization.Organization.t()],
          next_page_token: String.t()
        }
  defstruct [:status, :organizations, :next_page_token]

  field :status, 1, type: InternalApi.ResponseStatus
  field :organizations, 2, repeated: true, type: InternalApi.Organization.Organization
  field :next_page_token, 3, type: :string
end

defmodule InternalApi.Organization.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          creator_id: String.t(),
          organization_name: String.t(),
          organization_username: String.t()
        }
  defstruct [:creator_id, :organization_name, :organization_username]

  field :creator_id, 1, type: :string
  field :organization_name, 2, type: :string
  field :organization_username, 3, type: :string
end

defmodule InternalApi.Organization.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          organization: InternalApi.Organization.Organization.t()
        }
  defstruct [:status, :organization]

  field :status, 1, type: InternalApi.ResponseStatus
  field :organization, 2, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization: InternalApi.Organization.Organization.t()
        }
  defstruct [:organization]

  field :organization, 1, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          organization: InternalApi.Organization.Organization.t()
        }
  defstruct [:status, :organization]

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
  defstruct [:is_valid, :errors]

  field :is_valid, 1, type: :bool
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
  defstruct [:user_id, :org_id, :org_username]

  field :user_id, 1, type: :string
  field :org_id, 3, type: :string
  field :org_username, 4, type: :string
end

defmodule InternalApi.Organization.IsMemberResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          is_member: boolean
        }
  defstruct [:status, :is_member]

  field :status, 1, type: InternalApi.ResponseStatus
  field :is_member, 2, type: :bool
end

defmodule InternalApi.Organization.IsOwnerRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t()
        }
  defstruct [:user_id, :org_id]

  field :user_id, 1, type: :string
  field :org_id, 2, type: :string
end

defmodule InternalApi.Organization.IsOwnerResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          is_owner: boolean
        }
  defstruct [:status, :is_owner]

  field :status, 1, type: InternalApi.ResponseStatus
  field :is_owner, 2, type: :bool
end

defmodule InternalApi.Organization.MakeOwnerRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          owner_id: String.t()
        }
  defstruct [:org_id, :owner_id]

  field :org_id, 1, type: :string
  field :owner_id, 2, type: :string
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
  defstruct [:org_id, :org_username, :only_members, :name_contains]

  field :org_id, 1, type: :string
  field :org_username, 2, type: :string
  field :only_members, 3, type: :bool
  field :name_contains, 4, type: :string
end

defmodule InternalApi.Organization.MembersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          members: [InternalApi.Organization.Member.t()],
          not_logged_in_members: [InternalApi.Organization.Member.t()]
        }
  defstruct [:status, :members, :not_logged_in_members]

  field :status, 1, type: InternalApi.ResponseStatus
  field :members, 2, repeated: true, type: InternalApi.Organization.Member
  field :not_logged_in_members, 3, repeated: true, type: InternalApi.Organization.Member
end

defmodule InternalApi.Organization.AddMemberRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          creator_id: String.t(),
          username: String.t()
        }
  defstruct [:org_id, :creator_id, :username]

  field :org_id, 1, type: :string
  field :creator_id, 2, type: :string
  field :username, 3, type: :string
end

defmodule InternalApi.Organization.AddMemberResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          member: InternalApi.Organization.Member.t()
        }
  defstruct [:status, :member]

  field :status, 1, type: Google.Rpc.Status
  field :member, 2, type: InternalApi.Organization.Member
end

defmodule InternalApi.Organization.AddMembersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          creator_id: String.t(),
          members_data: [InternalApi.Organization.AddMembersRequest.MemberData.t()]
        }
  defstruct [:org_id, :creator_id, :members_data]

  field :org_id, 1, type: :string
  field :creator_id, 2, type: :string

  field :members_data, 3,
    repeated: true,
    type: InternalApi.Organization.AddMembersRequest.MemberData
end

defmodule InternalApi.Organization.AddMembersRequest.MemberData do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          github_username: String.t(),
          github_uid: String.t(),
          invite_email: String.t()
        }
  defstruct [:github_username, :github_uid, :invite_email]

  field :github_username, 1, type: :string
  field :github_uid, 2, type: :string
  field :invite_email, 3, type: :string
end

defmodule InternalApi.Organization.AddMembersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          members: [InternalApi.Organization.Member.t()]
        }
  defstruct [:members]

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
  defstruct [:org_id, :membership_id, :user_id]

  field :org_id, 1, type: :string
  field :membership_id, 3, type: :string
  field :user_id, 4, type: :string
end

defmodule InternalApi.Organization.DeleteMemberResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t()
        }
  defstruct [:status]

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.SuspendRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          origin: String.t(),
          description: String.t(),
          reason: integer
        }
  defstruct [:org_id, :origin, :description, :reason]

  field :org_id, 1, type: :string
  field :origin, 2, type: :string
  field :description, 3, type: :string
  field :reason, 4, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.SuspendResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t()
        }
  defstruct [:status]

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.SetOpenSourceRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.Organization.SetOpenSourceResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization: InternalApi.Organization.Organization.t()
        }
  defstruct [:organization]

  field :organization, 1, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UnsuspendRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          origin: String.t(),
          description: String.t(),
          reason: integer
        }
  defstruct [:org_id, :origin, :description, :reason]

  field :org_id, 1, type: :string
  field :origin, 3, type: :string
  field :description, 2, type: :string
  field :reason, 4, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.UnsuspendResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t()
        }
  defstruct [:status]

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.VerifyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.Organization.ListSuspensionsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.Organization.ListSuspensionsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: Google.Rpc.Status.t(),
          suspensions: [InternalApi.Organization.Suspension.t()]
        }
  defstruct [:status, :suspensions]

  field :status, 1, type: Google.Rpc.Status
  field :suspensions, 2, repeated: true, type: InternalApi.Organization.Suspension
end

defmodule InternalApi.Organization.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.Organization.RestoreRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.Organization.Organization do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_username: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          avatar_url: String.t(),
          org_id: String.t(),
          name: String.t(),
          owner_id: String.t(),
          suspended: boolean,
          open_source: boolean,
          verified: boolean,
          restricted: boolean,
          ip_allow_list: [String.t()],
          allowed_id_providers: [String.t()],
          deny_member_workflows: boolean,
          deny_non_member_workflows: boolean,
          settings: [InternalApi.Organization.OrganizationSetting.t()]
        }
  defstruct [
    :org_username,
    :created_at,
    :avatar_url,
    :org_id,
    :name,
    :owner_id,
    :suspended,
    :open_source,
    :verified,
    :restricted,
    :ip_allow_list,
    :allowed_id_providers,
    :deny_member_workflows,
    :deny_non_member_workflows,
    :settings
  ]

  field :org_username, 1, type: :string
  field :created_at, 2, type: Google.Protobuf.Timestamp
  field :avatar_url, 3, type: :string
  field :org_id, 4, type: :string
  field :name, 5, type: :string
  field :owner_id, 6, type: :string
  field :suspended, 7, type: :bool
  field :open_source, 9, type: :bool
  field :verified, 10, type: :bool
  field :restricted, 11, type: :bool
  field :ip_allow_list, 12, repeated: true, type: :string
  field :allowed_id_providers, 13, repeated: true, type: :string
  field :deny_member_workflows, 14, type: :bool
  field :deny_non_member_workflows, 15, type: :bool
  field :settings, 16, repeated: true, type: InternalApi.Organization.OrganizationSetting
end

defmodule InternalApi.Organization.Suspension do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          origin: String.t(),
          description: String.t(),
          reason: integer,
          created_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:origin, :description, :reason, :created_at]

  field :origin, 1, type: :string
  field :description, 2, type: :string
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
  field :created_at, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.Suspension.Reason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :INSUFFICIENT_FUNDS, 0
  field :ACCOUNT_AT_RISK, 1
  field :VIOLATION_OF_TOS, 2
end

defmodule InternalApi.Organization.Member do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          screen_name: String.t(),
          avatar_url: String.t(),
          user_id: String.t(),
          role: integer,
          invited_at: Google.Protobuf.Timestamp.t(),
          membership_id: String.t(),
          github_username: String.t(),
          github_uid: String.t()
        }
  defstruct [
    :screen_name,
    :avatar_url,
    :user_id,
    :role,
    :invited_at,
    :membership_id,
    :github_username,
    :github_uid
  ]

  field :screen_name, 1, type: :string
  field :avatar_url, 2, type: :string
  field :user_id, 3, type: :string
  field :role, 4, type: InternalApi.Organization.Member.Role, enum: true
  field :invited_at, 5, type: Google.Protobuf.Timestamp
  field :membership_id, 6, type: :string
  field :github_username, 7, type: :string
  field :github_uid, 8, type: :string
end

defmodule InternalApi.Organization.Member.Role do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :MEMBER, 0
  field :OWNER, 1
  field :ADMIN, 2
end

defmodule InternalApi.Organization.OrganizationSetting do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }
  defstruct [:key, :value]

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule InternalApi.Organization.RepositoryIntegratorsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.Organization.RepositoryIntegratorsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          primary: integer,
          enabled: [integer],
          available: [integer]
        }
  defstruct [:primary, :enabled, :available]

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

defmodule InternalApi.Organization.FetchOrganizationContactsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.Organization.FetchOrganizationContactsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_contacts: [InternalApi.Organization.OrganizationContact.t()]
        }
  defstruct [:org_contacts]

  field :org_contacts, 1, repeated: true, type: InternalApi.Organization.OrganizationContact
end

defmodule InternalApi.Organization.ModifyOrganizationContactRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_contact: InternalApi.Organization.OrganizationContact.t()
        }
  defstruct [:org_contact]

  field :org_contact, 1, type: InternalApi.Organization.OrganizationContact
end

defmodule InternalApi.Organization.ModifyOrganizationContactResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Organization.OrganizationContact do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          type: integer,
          name: String.t(),
          email: String.t(),
          phone: String.t()
        }
  defstruct [:org_id, :type, :name, :email, :phone]

  field :org_id, 1, type: :string
  field :type, 2, type: InternalApi.Organization.OrganizationContact.ContactType, enum: true
  field :name, 3, type: :string
  field :email, 4, type: :string
  field :phone, 5, type: :string
end

defmodule InternalApi.Organization.OrganizationContact.ContactType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :CONTACT_TYPE_UNSPECIFIED, 0
  field :CONTACT_TYPE_MAIN, 1
  field :CONTACT_TYPE_FINANCES, 2
  field :CONTACT_TYPE_SECURITY, 3
end

defmodule InternalApi.Organization.FetchOrganizationSettingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }
  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.Organization.FetchOrganizationSettingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          settings: [InternalApi.Organization.OrganizationSetting.t()]
        }
  defstruct [:settings]

  field :settings, 1, repeated: true, type: InternalApi.Organization.OrganizationSetting
end

defmodule InternalApi.Organization.ModifyOrganizationSettingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          settings: [InternalApi.Organization.OrganizationSetting.t()]
        }
  defstruct [:org_id, :settings]

  field :org_id, 1, type: :string
  field :settings, 2, repeated: true, type: InternalApi.Organization.OrganizationSetting
end

defmodule InternalApi.Organization.ModifyOrganizationSettingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          settings: [InternalApi.Organization.OrganizationSetting.t()]
        }
  defstruct [:settings]

  field :settings, 1, repeated: true, type: InternalApi.Organization.OrganizationSetting
end

defmodule InternalApi.Organization.OrganizationCreated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field :org_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationDeleted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field :org_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationUpdated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field :org_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationBlocked do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          reason: integer
        }
  defstruct [:org_id, :timestamp, :reason]

  field :org_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationSuspensionCreated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          reason: integer
        }
  defstruct [:org_id, :timestamp, :reason]

  field :org_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationSuspensionRemoved do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          reason: integer
        }
  defstruct [:org_id, :timestamp, :reason]

  field :org_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationUnblocked do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field :org_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationDailyUpdate do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_username: String.t(),
          org_name: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          projects_count: integer,
          member_count: integer,
          invited_count: integer,
          owner_id: String.t(),
          owner_email: String.t(),
          owner_owned_orgs_count: integer,
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :org_id,
    :org_username,
    :org_name,
    :created_at,
    :projects_count,
    :member_count,
    :invited_count,
    :owner_id,
    :owner_email,
    :owner_owned_orgs_count,
    :timestamp
  ]

  field :org_id, 1, type: :string
  field :org_username, 2, type: :string
  field :org_name, 3, type: :string
  field :created_at, 4, type: Google.Protobuf.Timestamp
  field :projects_count, 5, type: :int32
  field :member_count, 6, type: :int32
  field :invited_count, 7, type: :int32
  field :owner_id, 8, type: :string
  field :owner_email, 9, type: :string
  field :owner_owned_orgs_count, 10, type: :int32
  field :timestamp, 11, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationRestored do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:org_id, :timestamp]

  field :org_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Organization.OrganizationService"

  rpc :Describe,
      InternalApi.Organization.DescribeRequest,
      InternalApi.Organization.DescribeResponse

  rpc :DescribeMany,
      InternalApi.Organization.DescribeManyRequest,
      InternalApi.Organization.DescribeManyResponse

  rpc :List, InternalApi.Organization.ListRequest, InternalApi.Organization.ListResponse
  rpc :Create, InternalApi.Organization.CreateRequest, InternalApi.Organization.CreateResponse
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

  rpc :Destroy, InternalApi.Organization.DestroyRequest, Google.Protobuf.Empty
  rpc :Restore, InternalApi.Organization.RestoreRequest, Google.Protobuf.Empty

  rpc :RepositoryIntegrators,
      InternalApi.Organization.RepositoryIntegratorsRequest,
      InternalApi.Organization.RepositoryIntegratorsResponse

  rpc :FetchOrganizationContacts,
      InternalApi.Organization.FetchOrganizationContactsRequest,
      InternalApi.Organization.FetchOrganizationContactsResponse

  rpc :ModifyOrganizationContact,
      InternalApi.Organization.ModifyOrganizationContactRequest,
      InternalApi.Organization.ModifyOrganizationContactResponse

  rpc :FetchOrganizationSettings,
      InternalApi.Organization.FetchOrganizationSettingsRequest,
      InternalApi.Organization.FetchOrganizationSettingsResponse

  rpc :ModifyOrganizationSettings,
      InternalApi.Organization.ModifyOrganizationSettingsRequest,
      InternalApi.Organization.ModifyOrganizationSettingsResponse
end

defmodule InternalApi.Organization.OrganizationService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Organization.OrganizationService.Service
end
