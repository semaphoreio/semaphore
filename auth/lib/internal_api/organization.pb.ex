defmodule InternalApi.Organization.ListRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :BY_NAME_ASC, 0
  field :BY_CREATION_TIME_ASC, 1
end

defmodule InternalApi.Organization.Suspension.Reason do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :INSUFFICIENT_FUNDS, 0
  field :ACCOUNT_AT_RISK, 1
  field :VIOLATION_OF_TOS, 2
end

defmodule InternalApi.Organization.Member.Role do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :MEMBER, 0
  field :OWNER, 1
  field :ADMIN, 2
end

defmodule InternalApi.Organization.OrganizationContact.ContactType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :CONTACT_TYPE_UNSPECIFIED, 0
  field :CONTACT_TYPE_MAIN, 1
  field :CONTACT_TYPE_FINANCES, 2
  field :CONTACT_TYPE_SECURITY, 3
end

defmodule InternalApi.Organization.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :org_username, 2, type: :string, json_name: "orgUsername"
  field :include_quotas, 3, type: :bool, json_name: "includeQuotas"
  field :soft_deleted, 4, type: :bool, json_name: "softDeleted"
end

defmodule InternalApi.Organization.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :organization, 2, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.DescribeManyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_ids, 1, repeated: true, type: :string, json_name: "orgIds"
  field :soft_deleted, 2, type: :bool, json_name: "softDeleted"
end

defmodule InternalApi.Organization.DescribeManyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :organizations, 1, repeated: true, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :user_id, 2, type: :string, json_name: "userId"
  field :created_at_gt, 3, type: Google.Protobuf.Timestamp, json_name: "createdAtGt"
  field :order, 4, type: InternalApi.Organization.ListRequest.Order, enum: true
  field :page_size, 5, type: :int32, json_name: "pageSize"
  field :page_token, 6, type: :string, json_name: "pageToken"
  field :soft_deleted, 7, type: :bool, json_name: "softDeleted"
end

defmodule InternalApi.Organization.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :organizations, 2, repeated: true, type: InternalApi.Organization.Organization
  field :next_page_token, 3, type: :string, json_name: "nextPageToken"
end

defmodule InternalApi.Organization.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :creator_id, 1, type: :string, json_name: "creatorId"
  field :organization_name, 2, type: :string, json_name: "organizationName"
  field :organization_username, 3, type: :string, json_name: "organizationUsername"
end

defmodule InternalApi.Organization.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :organization, 2, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UpdateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :organization, 1, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UpdateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: Google.Rpc.Status
  field :organization, 2, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.IsValidResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :is_valid, 1, type: :bool, json_name: "isValid"
  field :errors, 2, type: :string
end

defmodule InternalApi.Organization.IsMemberRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :org_id, 3, type: :string, json_name: "orgId"
  field :org_username, 4, type: :string, json_name: "orgUsername"
end

defmodule InternalApi.Organization.IsMemberResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :is_member, 2, type: :bool, json_name: "isMember"
end

defmodule InternalApi.Organization.IsOwnerRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.IsOwnerResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :is_owner, 2, type: :bool, json_name: "isOwner"
end

defmodule InternalApi.Organization.MakeOwnerRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :owner_id, 2, type: :string, json_name: "ownerId"
end

defmodule InternalApi.Organization.MembersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :org_username, 2, type: :string, json_name: "orgUsername"
  field :only_members, 3, type: :bool, json_name: "onlyMembers"
  field :name_contains, 4, type: :string, json_name: "nameContains"
end

defmodule InternalApi.Organization.MembersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :members, 2, repeated: true, type: InternalApi.Organization.Member

  field :not_logged_in_members, 3,
    repeated: true,
    type: InternalApi.Organization.Member,
    json_name: "notLoggedInMembers"
end

defmodule InternalApi.Organization.AddMemberRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :creator_id, 2, type: :string, json_name: "creatorId"
  field :username, 3, type: :string
end

defmodule InternalApi.Organization.AddMemberResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: Google.Rpc.Status
  field :member, 2, type: InternalApi.Organization.Member
end

defmodule InternalApi.Organization.AddMembersRequest.MemberData do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :github_username, 1, type: :string, json_name: "githubUsername"
  field :github_uid, 2, type: :string, json_name: "githubUid"
  field :invite_email, 3, type: :string, json_name: "inviteEmail"
end

defmodule InternalApi.Organization.AddMembersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :creator_id, 2, type: :string, json_name: "creatorId"

  field :members_data, 3,
    repeated: true,
    type: InternalApi.Organization.AddMembersRequest.MemberData,
    json_name: "membersData"
end

defmodule InternalApi.Organization.AddMembersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :members, 1, repeated: true, type: InternalApi.Organization.Member
end

defmodule InternalApi.Organization.DeleteMemberRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :membership_id, 3, type: :string, json_name: "membershipId"
  field :user_id, 4, type: :string, json_name: "userId"
end

defmodule InternalApi.Organization.DeleteMemberResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.SuspendRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :origin, 2, type: :string
  field :description, 3, type: :string
  field :reason, 4, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.SuspendResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.SetOpenSourceRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.SetOpenSourceResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :organization, 1, type: InternalApi.Organization.Organization
end

defmodule InternalApi.Organization.UnsuspendRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :origin, 3, type: :string
  field :description, 2, type: :string
  field :reason, 4, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.UnsuspendResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: Google.Rpc.Status
end

defmodule InternalApi.Organization.VerifyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.ListSuspensionsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.ListSuspensionsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :status, 1, type: Google.Rpc.Status
  field :suspensions, 2, repeated: true, type: InternalApi.Organization.Suspension
end

defmodule InternalApi.Organization.DestroyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.RestoreRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.Organization do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

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
  field :allowed_id_providers, 13, repeated: true, type: :string, json_name: "allowedIdProviders"
  field :deny_member_workflows, 14, type: :bool, json_name: "denyMemberWorkflows"
  field :deny_non_member_workflows, 15, type: :bool, json_name: "denyNonMemberWorkflows"
  field :settings, 16, repeated: true, type: InternalApi.Organization.OrganizationSetting
end

defmodule InternalApi.Organization.Suspension do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :origin, 1, type: :string
  field :description, 2, type: :string
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
  field :created_at, 4, type: Google.Protobuf.Timestamp, json_name: "createdAt"
end

defmodule InternalApi.Organization.Member do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :screen_name, 1, type: :string, json_name: "screenName"
  field :avatar_url, 2, type: :string, json_name: "avatarUrl"
  field :user_id, 3, type: :string, json_name: "userId"
  field :role, 4, type: InternalApi.Organization.Member.Role, enum: true
  field :invited_at, 5, type: Google.Protobuf.Timestamp, json_name: "invitedAt"
  field :membership_id, 6, type: :string, json_name: "membershipId"
  field :github_username, 7, type: :string, json_name: "githubUsername"
  field :github_uid, 8, type: :string, json_name: "githubUid"
end

defmodule InternalApi.Organization.OrganizationSetting do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule InternalApi.Organization.RepositoryIntegratorsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.RepositoryIntegratorsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

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

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.FetchOrganizationContactsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_contacts, 1,
    repeated: true,
    type: InternalApi.Organization.OrganizationContact,
    json_name: "orgContacts"
end

defmodule InternalApi.Organization.ModifyOrganizationContactRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_contact, 1,
    type: InternalApi.Organization.OrganizationContact,
    json_name: "orgContact"
end

defmodule InternalApi.Organization.ModifyOrganizationContactResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.Organization.OrganizationContact do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :type, 2, type: InternalApi.Organization.OrganizationContact.ContactType, enum: true
  field :name, 3, type: :string
  field :email, 4, type: :string
  field :phone, 5, type: :string
end

defmodule InternalApi.Organization.FetchOrganizationSettingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Organization.FetchOrganizationSettingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :settings, 1, repeated: true, type: InternalApi.Organization.OrganizationSetting
end

defmodule InternalApi.Organization.ModifyOrganizationSettingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :settings, 2, repeated: true, type: InternalApi.Organization.OrganizationSetting
end

defmodule InternalApi.Organization.ModifyOrganizationSettingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :settings, 1, repeated: true, type: InternalApi.Organization.OrganizationSetting
end

defmodule InternalApi.Organization.OrganizationCreated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationDeleted do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationUpdated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationBlocked do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationSuspensionCreated do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationSuspensionRemoved do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
  field :reason, 3, type: InternalApi.Organization.Suspension.Reason, enum: true
end

defmodule InternalApi.Organization.OrganizationUnblocked do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationDailyUpdate do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

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

defmodule InternalApi.Organization.OrganizationRestored do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Organization.OrganizationService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Organization.OrganizationService",
    protoc_gen_elixir_version: "0.12.0"

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