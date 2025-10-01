defmodule InternalApi.Guard.Action do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :CREATE, 0
  field :READ, 1
  field :UPDATE, 2
  field :DELETE, 3
end

defmodule InternalApi.Guard.Resource.Type do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :Project, 0
  field :Organization, 1
  field :Secret, 2
  field :Member, 3
  field :Pipeline, 4
  field :Dashboard, 5
  field :Coupon, 6
  field :Periodic, 7
  field :Job, 8
  field :Workflow, 9
end

defmodule InternalApi.Guard.Role.Name do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :Admin, 0
  field :Owner, 1
end

defmodule InternalApi.Guard.Operation.Name do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :ViewOrganizationSettings, 0
  field :ViewProjectSettings, 1
  field :AddProject, 2
  field :DeleteProject, 3
  field :ManagePeople, 4
  field :ManageSecrets, 5
  field :ManageProjectSettings, 6
  field :ManageOrganizationSettings, 7
  field :ViewProjectScheduler, 8
  field :ManageProjectScheduler, 9
  field :ViewProject, 10
  field :ViewSelfHostedAgentTypes, 11
  field :ManageSelfHostedAgentTypes, 12
  field :ManageBilling, 13
  field :ViewBilling, 14
  field :ViewSecretsPolicySettings, 15
  field :ManageSecretsPolicySettings, 16
  field :ViewSecrets, 17
  field :ViewOrganizationIpAllowList, 18
  field :ManageOrganizationIpAllowList, 19
  field :ManageProjectSecrets, 20
  field :ViewDeploymentTargets, 21
  field :ManageDeploymentTargets, 22
end

defmodule InternalApi.Guard.ChangeEmailRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :requester_id, 1, type: :string, json_name: "requesterId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :email, 3, type: :string
end

defmodule InternalApi.Guard.ChangeEmailResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :email, 1, type: :string
  field :msg, 2, type: :string
end

defmodule InternalApi.Guard.ResetPasswordRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :requester_id, 1, type: :string, json_name: "requesterId"
  field :user_id, 2, type: :string, json_name: "userId"
end

defmodule InternalApi.Guard.ResetPasswordResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :password, 1, type: :string
  field :msg, 2, type: :string
end

defmodule InternalApi.Guard.CreateMemberRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :inviter_id, 1, type: :string, json_name: "inviterId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :email, 3, type: :string
  field :name, 4, type: :string
end

defmodule InternalApi.Guard.CreateMemberResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :password, 1, type: :string
  field :msg, 2, type: :string
end

defmodule InternalApi.Guard.InviteCollaboratorsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :inviter_id, 1, type: :string, json_name: "inviterId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :invitees, 3, repeated: true, type: InternalApi.Guard.Invitee
end

defmodule InternalApi.Guard.InviteCollaboratorsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :invitees, 1, repeated: true, type: InternalApi.Guard.Invitee
end

defmodule InternalApi.Guard.Invitee do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :email, 1, type: :string
  field :name, 2, type: :string
  field :provider, 3, type: InternalApi.User.RepositoryProvider
end

defmodule InternalApi.Guard.OrganizationMembersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :name_contains, 4, type: :string, json_name: "nameContains"
end

defmodule InternalApi.Guard.OrganizationMembersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :members, 1, repeated: true, type: InternalApi.Guard.OrganizationMember
end

defmodule InternalApi.Guard.OrganizationMember do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :display_name, 2, type: :string, json_name: "displayName"
  field :avatar_url, 3, type: :string, json_name: "avatarUrl"
  field :organization_role, 4, type: :string, json_name: "organizationRole"

  field :repository_providers, 5,
    repeated: true,
    type: InternalApi.User.RepositoryProvider,
    json_name: "repositoryProviders"
end

defmodule InternalApi.Guard.ProjectMembersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :name_contains, 4, type: :string, json_name: "nameContains"
end

defmodule InternalApi.Guard.ProjectMembersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :members, 1, repeated: true, type: InternalApi.Guard.ProjectMember
end

defmodule InternalApi.Guard.ProjectMember do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :display_name, 2, type: :string, json_name: "displayName"
  field :avatar_url, 3, type: :string, json_name: "avatarUrl"
  field :organization_role, 4, type: :string, json_name: "organizationRole"
  field :project_role, 5, type: :string, json_name: "projectRole"

  field :repository_providers, 6,
    repeated: true,
    type: InternalApi.User.RepositoryProvider,
    json_name: "repositoryProviders"
end

defmodule InternalApi.Guard.RepositoryCollaboratorsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :project_id, 2, type: :string, json_name: "projectId"
end

defmodule InternalApi.Guard.RepositoryCollaboratorsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :collaborators, 1, repeated: true, type: InternalApi.Guard.RepositoryCollaborator
end

defmodule InternalApi.Guard.RepositoryCollaborator do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :display_name, 1, type: :string, json_name: "displayName"
  field :avatar_url, 2, type: :string, json_name: "avatarUrl"

  field :repository_provider, 3,
    type: InternalApi.User.RepositoryProvider,
    json_name: "repositoryProvider"
end

defmodule InternalApi.Guard.InvitationsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Guard.InvitationsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :invitations, 1, repeated: true, type: InternalApi.Guard.Invitation
end

defmodule InternalApi.Guard.Invitation do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :invited_at, 2, type: Google.Protobuf.Timestamp, json_name: "invitedAt"
  field :display_name, 3, type: :string, json_name: "displayName"
  field :avatar_url, 4, type: :string, json_name: "avatarUrl"
end

defmodule InternalApi.Guard.FilterRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :resources, 1, repeated: true, type: InternalApi.Guard.Resource
  field :action, 2, type: InternalApi.Guard.Action, enum: true
  field :user_id, 3, type: :string, json_name: "userId"
  field :org_id, 4, type: :string, json_name: "orgId"
end

defmodule InternalApi.Guard.FilterResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :resources, 1, repeated: true, type: InternalApi.Guard.Resource
end

defmodule InternalApi.Guard.RefreshRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :resources, 1, repeated: true, type: InternalApi.Guard.Resource
end

defmodule InternalApi.Guard.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :project_ids, 1, repeated: true, type: :string, json_name: "projectIds"
end

defmodule InternalApi.Guard.RefreshResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Guard.ListResponse.User do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :id, 1, type: :string
  field :avatar_url, 2, type: :string, json_name: "avatarUrl"
  field :login, 3, type: :string
  field :name, 4, type: :string
  field :projects, 5, repeated: true, type: :string
  field :email, 6, type: :string
end

defmodule InternalApi.Guard.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :users, 2, repeated: true, type: InternalApi.Guard.ListResponse.User
end

defmodule InternalApi.Guard.ListResourcesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :type, 3, type: InternalApi.Guard.Resource.Type, enum: true
  field :action, 4, type: InternalApi.Guard.Action, enum: true
end

defmodule InternalApi.Guard.ListResourcesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :ids, 2, repeated: true, type: :string
end

defmodule InternalApi.Guard.ListRolesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :org_id, 1, type: :string, json_name: "orgId"
end

defmodule InternalApi.Guard.ListRolesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
  field :roles, 2, repeated: true, type: InternalApi.Guard.Role
end

defmodule InternalApi.Guard.AddRolesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :roles, 1, repeated: true, type: InternalApi.Guard.Role
end

defmodule InternalApi.Guard.AddRolesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Guard.DeleteRolesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :roles, 1, repeated: true, type: InternalApi.Guard.Role
end

defmodule InternalApi.Guard.DeleteRolesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :status, 1, type: InternalApi.ResponseStatus
end

defmodule InternalApi.Guard.Resource do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :name, 1, type: :string
  field :id, 2, type: :string
  field :type, 3, type: InternalApi.Guard.Resource.Type, enum: true
  field :project_id, 4, type: :string, json_name: "projectId"
  field :org_id, 5, type: :string, json_name: "orgId"
end

defmodule InternalApi.Guard.Role do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :name, 3, type: InternalApi.Guard.Role.Name, enum: true
end

defmodule InternalApi.Guard.IsAuthorizedRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :objects, 1, repeated: true, type: InternalApi.Guard.AuthorizationObject
end

defmodule InternalApi.Guard.IsAuthorizedResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :objects, 1, repeated: true, type: InternalApi.Guard.AuthorizationObject
end

defmodule InternalApi.Guard.AuthorizationObject do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :subject, 1, type: InternalApi.Guard.Subject
  field :operation, 2, type: InternalApi.Guard.Operation
  field :authorized, 3, type: :bool
  field :message, 4, type: :string
end

defmodule InternalApi.Guard.Subject do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.Guard.Operation do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :name, 1, type: InternalApi.Guard.Operation.Name, enum: true
  field :project_id, 2, type: :string, json_name: "projectId"
end

defmodule InternalApi.Guard.AuthorizationEvent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :project_id, 2, type: :string, json_name: "projectId"
  field :user_id, 3, type: :string, json_name: "userId"
  field :timestamp, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Guard.Guard.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Guard.Guard", protoc_gen_elixir_version: "0.13.0"

  rpc :Refresh, InternalApi.Guard.RefreshRequest, InternalApi.Guard.RefreshResponse

  rpc :List, InternalApi.Guard.ListRequest, InternalApi.Guard.ListResponse

  rpc :ListResources,
      InternalApi.Guard.ListResourcesRequest,
      InternalApi.Guard.ListResourcesResponse

  rpc :Filter, InternalApi.Guard.FilterRequest, InternalApi.Guard.FilterResponse

  rpc :ListRoles, InternalApi.Guard.ListRolesRequest, InternalApi.Guard.ListRolesResponse

  rpc :AddRoles, InternalApi.Guard.AddRolesRequest, InternalApi.Guard.AddRolesResponse

  rpc :DeleteRoles, InternalApi.Guard.DeleteRolesRequest, InternalApi.Guard.DeleteRolesResponse

  rpc :IsAuthorized, InternalApi.Guard.IsAuthorizedRequest, InternalApi.Guard.IsAuthorizedResponse

  rpc :OrganizationMembers,
      InternalApi.Guard.OrganizationMembersRequest,
      InternalApi.Guard.OrganizationMembersResponse

  rpc :ProjectMembers,
      InternalApi.Guard.ProjectMembersRequest,
      InternalApi.Guard.ProjectMembersResponse

  rpc :RepositoryCollaborators,
      InternalApi.Guard.RepositoryCollaboratorsRequest,
      InternalApi.Guard.RepositoryCollaboratorsResponse

  rpc :Invitations, InternalApi.Guard.InvitationsRequest, InternalApi.Guard.InvitationsResponse

  rpc :InviteCollaborators,
      InternalApi.Guard.InviteCollaboratorsRequest,
      InternalApi.Guard.InviteCollaboratorsResponse

  rpc :CreateMember, InternalApi.Guard.CreateMemberRequest, InternalApi.Guard.CreateMemberResponse

  rpc :ResetPassword,
      InternalApi.Guard.ResetPasswordRequest,
      InternalApi.Guard.ResetPasswordResponse

  rpc :ChangeEmail, InternalApi.Guard.ChangeEmailRequest, InternalApi.Guard.ChangeEmailResponse
end

defmodule InternalApi.Guard.Guard.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Guard.Guard.Service
end