defmodule InternalApi.McpGrant.McpGrant do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :id, 1, type: :string
  field :user_id, 2, type: :string, json_name: "userId"
  field :client_id, 3, type: :string, json_name: "clientId"
  field :client_name, 4, type: :string, json_name: "clientName"
  field :tool_scopes, 5, repeated: true, type: :string, json_name: "toolScopes"

  field :org_grants, 6,
    repeated: true,
    type: InternalApi.McpGrant.OrgGrant,
    json_name: "orgGrants"

  field :project_grants, 7,
    repeated: true,
    type: InternalApi.McpGrant.ProjectGrant,
    json_name: "projectGrants"

  field :created_at, 8, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :expires_at, 9, type: Google.Protobuf.Timestamp, json_name: "expiresAt"
  field :revoked_at, 10, type: Google.Protobuf.Timestamp, json_name: "revokedAt"
  field :last_used_at, 11, type: Google.Protobuf.Timestamp, json_name: "lastUsedAt"
end

defmodule InternalApi.McpGrant.OrgGrant do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :org_name, 2, type: :string, json_name: "orgName"
  field :can_view, 3, type: :bool, json_name: "canView"
  field :can_run_workflows, 4, type: :bool, json_name: "canRunWorkflows"
end

defmodule InternalApi.McpGrant.ProjectGrant do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :project_name, 3, type: :string, json_name: "projectName"
  field :can_view, 4, type: :bool, json_name: "canView"
  field :can_run_workflows, 5, type: :bool, json_name: "canRunWorkflows"
  field :can_view_logs, 6, type: :bool, json_name: "canViewLogs"
end

defmodule InternalApi.McpGrant.OrgGrantInput do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :can_view, 2, type: :bool, json_name: "canView"
  field :can_run_workflows, 3, type: :bool, json_name: "canRunWorkflows"
end

defmodule InternalApi.McpGrant.ProjectGrantInput do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :can_view, 3, type: :bool, json_name: "canView"
  field :can_run_workflows, 4, type: :bool, json_name: "canRunWorkflows"
  field :can_view_logs, 5, type: :bool, json_name: "canViewLogs"
end

defmodule InternalApi.McpGrant.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :client_id, 2, type: :string, json_name: "clientId"
  field :client_name, 3, type: :string, json_name: "clientName"
  field :tool_scopes, 4, repeated: true, type: :string, json_name: "toolScopes"

  field :org_grants, 5,
    repeated: true,
    type: InternalApi.McpGrant.OrgGrantInput,
    json_name: "orgGrants"

  field :project_grants, 6,
    repeated: true,
    type: InternalApi.McpGrant.ProjectGrantInput,
    json_name: "projectGrants"

  field :expires_at, 7, type: Google.Protobuf.Timestamp, json_name: "expiresAt"
end

defmodule InternalApi.McpGrant.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant, 1, type: InternalApi.McpGrant.McpGrant
end

defmodule InternalApi.McpGrant.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :page_size, 2, type: :int32, json_name: "pageSize"
  field :page_token, 3, type: :string, json_name: "pageToken"
  field :include_revoked, 4, type: :bool, json_name: "includeRevoked"
end

defmodule InternalApi.McpGrant.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grants, 1, repeated: true, type: InternalApi.McpGrant.McpGrant
  field :next_page_token, 2, type: :string, json_name: "nextPageToken"
  field :total_count, 3, type: :int32, json_name: "totalCount"
end

defmodule InternalApi.McpGrant.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
end

defmodule InternalApi.McpGrant.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant, 1, type: InternalApi.McpGrant.McpGrant
end

defmodule InternalApi.McpGrant.UpdateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :tool_scopes, 3, repeated: true, type: :string, json_name: "toolScopes"

  field :org_grants, 4,
    repeated: true,
    type: InternalApi.McpGrant.OrgGrantInput,
    json_name: "orgGrants"

  field :project_grants, 5,
    repeated: true,
    type: InternalApi.McpGrant.ProjectGrantInput,
    json_name: "projectGrants"
end

defmodule InternalApi.McpGrant.UpdateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant, 1, type: InternalApi.McpGrant.McpGrant
end

defmodule InternalApi.McpGrant.DeleteRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
  field :user_id, 2, type: :string, json_name: "userId"
end

defmodule InternalApi.McpGrant.DeleteResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"
end

defmodule InternalApi.McpGrant.RevokeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
  field :user_id, 2, type: :string, json_name: "userId"
end

defmodule InternalApi.McpGrant.RevokeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant, 1, type: InternalApi.McpGrant.McpGrant
end

defmodule InternalApi.McpGrant.CheckOrgAccessRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
  field :org_id, 2, type: :string, json_name: "orgId"
end

defmodule InternalApi.McpGrant.CheckOrgAccessResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :allowed, 1, type: :bool
  field :can_view, 2, type: :bool, json_name: "canView"
  field :can_run_workflows, 3, type: :bool, json_name: "canRunWorkflows"
end

defmodule InternalApi.McpGrant.CheckProjectAccessRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
  field :project_id, 2, type: :string, json_name: "projectId"
end

defmodule InternalApi.McpGrant.CheckProjectAccessResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :allowed, 1, type: :bool
  field :can_view, 2, type: :bool, json_name: "canView"
  field :can_run_workflows, 3, type: :bool, json_name: "canRunWorkflows"
  field :can_view_logs, 4, type: :bool, json_name: "canViewLogs"
end

defmodule InternalApi.McpGrant.GetGrantRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
end

defmodule InternalApi.McpGrant.GetGrantResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant, 1, type: InternalApi.McpGrant.McpGrant
  field :is_valid, 2, type: :bool, json_name: "isValid"
end

defmodule InternalApi.McpGrant.FindExistingGrantRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :client_id, 2, type: :string, json_name: "clientId"
end

defmodule InternalApi.McpGrant.FindExistingGrantResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant, 1, type: InternalApi.McpGrant.McpGrant
  field :found, 2, type: :bool
end

defmodule InternalApi.McpGrant.ConsentChallenge do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :id, 1, type: :string
  field :user_id, 2, type: :string, json_name: "userId"
  field :client_id, 3, type: :string, json_name: "clientId"
  field :client_name, 4, type: :string, json_name: "clientName"
  field :redirect_uri, 5, type: :string, json_name: "redirectUri"
  field :code_challenge, 6, type: :string, json_name: "codeChallenge"
  field :code_challenge_method, 7, type: :string, json_name: "codeChallengeMethod"
  field :state, 8, type: :string
  field :requested_scope, 9, type: :string, json_name: "requestedScope"
  field :created_at, 10, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :expires_at, 11, type: Google.Protobuf.Timestamp, json_name: "expiresAt"
  field :consumed_at, 12, type: Google.Protobuf.Timestamp, json_name: "consumedAt"
end

defmodule InternalApi.McpGrant.GrantSelection do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :tool_scopes, 1, repeated: true, type: :string, json_name: "toolScopes"

  field :org_grants, 2,
    repeated: true,
    type: InternalApi.McpGrant.OrgGrantInput,
    json_name: "orgGrants"

  field :project_grants, 3,
    repeated: true,
    type: InternalApi.McpGrant.ProjectGrantInput,
    json_name: "projectGrants"
end

defmodule InternalApi.McpGrant.GrantableOrganization do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :org_name, 2, type: :string, json_name: "orgName"
  field :can_view, 3, type: :bool, json_name: "canView"
  field :can_run_workflows, 4, type: :bool, json_name: "canRunWorkflows"
end

defmodule InternalApi.McpGrant.GrantableProject do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :org_name, 3, type: :string, json_name: "orgName"
  field :project_name, 4, type: :string, json_name: "projectName"
  field :can_view, 5, type: :bool, json_name: "canView"
  field :can_run_workflows, 6, type: :bool, json_name: "canRunWorkflows"
  field :can_view_logs, 7, type: :bool, json_name: "canViewLogs"
end

defmodule InternalApi.McpGrant.CreateConsentChallengeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :user_id, 1, type: :string, json_name: "userId"
  field :client_id, 2, type: :string, json_name: "clientId"
  field :client_name, 3, type: :string, json_name: "clientName"
  field :redirect_uri, 4, type: :string, json_name: "redirectUri"
  field :code_challenge, 5, type: :string, json_name: "codeChallenge"
  field :code_challenge_method, 6, type: :string, json_name: "codeChallengeMethod"
  field :state, 7, type: :string
  field :requested_scope, 8, type: :string, json_name: "requestedScope"
end

defmodule InternalApi.McpGrant.CreateConsentChallengeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :challenge_id, 1, type: :string, json_name: "challengeId"
  field :expires_at, 2, type: Google.Protobuf.Timestamp, json_name: "expiresAt"
end

defmodule InternalApi.McpGrant.DescribeConsentChallengeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :challenge_id, 1, type: :string, json_name: "challengeId"
  field :user_id, 2, type: :string, json_name: "userId"
end

defmodule InternalApi.McpGrant.DescribeConsentChallengeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :challenge, 1, type: InternalApi.McpGrant.ConsentChallenge
  field :found_existing_grant, 2, type: :bool, json_name: "foundExistingGrant"
  field :existing_grant, 3, type: InternalApi.McpGrant.McpGrant, json_name: "existingGrant"

  field :default_selection, 4,
    type: InternalApi.McpGrant.GrantSelection,
    json_name: "defaultSelection"

  field :available_organizations, 5,
    repeated: true,
    type: InternalApi.McpGrant.GrantableOrganization,
    json_name: "availableOrganizations"

  field :available_projects, 6,
    repeated: true,
    type: InternalApi.McpGrant.GrantableProject,
    json_name: "availableProjects"
end

defmodule InternalApi.McpGrant.ApproveConsentChallengeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :challenge_id, 1, type: :string, json_name: "challengeId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :selection, 3, type: InternalApi.McpGrant.GrantSelection
end

defmodule InternalApi.McpGrant.ApproveConsentChallengeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
  field :authorization_code, 2, type: :string, json_name: "authorizationCode"
  field :redirect_uri, 3, type: :string, json_name: "redirectUri"
  field :state, 4, type: :string
  field :redirect_url, 5, type: :string, json_name: "redirectUrl"
  field :reused_existing_grant, 6, type: :bool, json_name: "reusedExistingGrant"
end

defmodule InternalApi.McpGrant.DenyConsentChallengeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :challenge_id, 1, type: :string, json_name: "challengeId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :error, 3, type: :string
  field :error_description, 4, type: :string, json_name: "errorDescription"
end

defmodule InternalApi.McpGrant.DenyConsentChallengeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :redirect_uri, 1, type: :string, json_name: "redirectUri"
  field :state, 2, type: :string
  field :redirect_url, 3, type: :string, json_name: "redirectUrl"
end

defmodule InternalApi.McpGrant.ResolveGrantForAuthRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :grant_id, 1, type: :string, json_name: "grantId"
  field :user_id, 2, type: :string, json_name: "userId"
end

defmodule InternalApi.McpGrant.ResolvedOrgPermissions do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :org_id, 1, type: :string, json_name: "orgId"
  field :permissions, 2, repeated: true, type: :string
end

defmodule InternalApi.McpGrant.ResolvedProjectPermissions do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :org_id, 2, type: :string, json_name: "orgId"
  field :permissions, 3, repeated: true, type: :string
end

defmodule InternalApi.McpGrant.ResolveGrantForAuthResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field :valid, 1, type: :bool
  field :invalid_reason, 2, type: :string, json_name: "invalidReason"
  field :grant, 3, type: InternalApi.McpGrant.McpGrant
  field :tool_scopes, 4, repeated: true, type: :string, json_name: "toolScopes"

  field :org_permissions, 5,
    repeated: true,
    type: InternalApi.McpGrant.ResolvedOrgPermissions,
    json_name: "orgPermissions"

  field :project_permissions, 6,
    repeated: true,
    type: InternalApi.McpGrant.ResolvedProjectPermissions,
    json_name: "projectPermissions"
end

defmodule InternalApi.McpGrant.McpGrantService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.McpGrant.McpGrantService",
    protoc_gen_elixir_version: "0.12.0"

  rpc :Create, InternalApi.McpGrant.CreateRequest, InternalApi.McpGrant.CreateResponse

  rpc :List, InternalApi.McpGrant.ListRequest, InternalApi.McpGrant.ListResponse

  rpc :Describe, InternalApi.McpGrant.DescribeRequest, InternalApi.McpGrant.DescribeResponse

  rpc :Update, InternalApi.McpGrant.UpdateRequest, InternalApi.McpGrant.UpdateResponse

  rpc :Delete, InternalApi.McpGrant.DeleteRequest, InternalApi.McpGrant.DeleteResponse

  rpc :Revoke, InternalApi.McpGrant.RevokeRequest, InternalApi.McpGrant.RevokeResponse

  rpc :CheckOrgAccess,
      InternalApi.McpGrant.CheckOrgAccessRequest,
      InternalApi.McpGrant.CheckOrgAccessResponse

  rpc :CheckProjectAccess,
      InternalApi.McpGrant.CheckProjectAccessRequest,
      InternalApi.McpGrant.CheckProjectAccessResponse

  rpc :GetGrant, InternalApi.McpGrant.GetGrantRequest, InternalApi.McpGrant.GetGrantResponse

  rpc :FindExistingGrant,
      InternalApi.McpGrant.FindExistingGrantRequest,
      InternalApi.McpGrant.FindExistingGrantResponse

  rpc :CreateConsentChallenge,
      InternalApi.McpGrant.CreateConsentChallengeRequest,
      InternalApi.McpGrant.CreateConsentChallengeResponse

  rpc :DescribeConsentChallenge,
      InternalApi.McpGrant.DescribeConsentChallengeRequest,
      InternalApi.McpGrant.DescribeConsentChallengeResponse

  rpc :ApproveConsentChallenge,
      InternalApi.McpGrant.ApproveConsentChallengeRequest,
      InternalApi.McpGrant.ApproveConsentChallengeResponse

  rpc :DenyConsentChallenge,
      InternalApi.McpGrant.DenyConsentChallengeRequest,
      InternalApi.McpGrant.DenyConsentChallengeResponse

  rpc :ResolveGrantForAuth,
      InternalApi.McpGrant.ResolveGrantForAuthRequest,
      InternalApi.McpGrant.ResolveGrantForAuthResponse
end

defmodule InternalApi.McpGrant.McpGrantService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.McpGrant.McpGrantService.Service
end