defmodule InternalApi.McpGrant.McpGrant do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          client_id: String.t(),
          client_name: String.t(),
          tool_scopes: [String.t()],
          org_grants: [InternalApi.McpGrant.OrgGrant.t()],
          project_grants: [InternalApi.McpGrant.ProjectGrant.t()],
          created_at: Google.Protobuf.Timestamp.t(),
          expires_at: Google.Protobuf.Timestamp.t(),
          revoked_at: Google.Protobuf.Timestamp.t(),
          last_used_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :id,
    :user_id,
    :client_id,
    :client_name,
    :tool_scopes,
    :org_grants,
    :project_grants,
    :created_at,
    :expires_at,
    :revoked_at,
    :last_used_at
  ]

  field(:id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:client_id, 3, type: :string)
  field(:client_name, 4, type: :string)
  field(:tool_scopes, 5, repeated: true, type: :string)
  field(:org_grants, 6, repeated: true, type: InternalApi.McpGrant.OrgGrant)
  field(:project_grants, 7, repeated: true, type: InternalApi.McpGrant.ProjectGrant)
  field(:created_at, 8, type: Google.Protobuf.Timestamp)
  field(:expires_at, 9, type: Google.Protobuf.Timestamp)
  field(:revoked_at, 10, type: Google.Protobuf.Timestamp)
  field(:last_used_at, 11, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.McpGrant.OrgGrant do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_name: String.t(),
          can_view: boolean,
          can_run_workflows: boolean
        }
  defstruct [:org_id, :org_name, :can_view, :can_run_workflows]

  field(:org_id, 1, type: :string)
  field(:org_name, 2, type: :string)
  field(:can_view, 3, type: :bool)
  field(:can_run_workflows, 4, type: :bool)
end

defmodule InternalApi.McpGrant.ProjectGrant do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          org_id: String.t(),
          project_name: String.t(),
          can_view: boolean,
          can_run_workflows: boolean,
          can_view_logs: boolean
        }
  defstruct [:project_id, :org_id, :project_name, :can_view, :can_run_workflows, :can_view_logs]

  field(:project_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:project_name, 3, type: :string)
  field(:can_view, 4, type: :bool)
  field(:can_run_workflows, 5, type: :bool)
  field(:can_view_logs, 6, type: :bool)
end

defmodule InternalApi.McpGrant.OrgGrantInput do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          can_view: boolean,
          can_run_workflows: boolean
        }
  defstruct [:org_id, :can_view, :can_run_workflows]

  field(:org_id, 1, type: :string)
  field(:can_view, 2, type: :bool)
  field(:can_run_workflows, 3, type: :bool)
end

defmodule InternalApi.McpGrant.ProjectGrantInput do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          org_id: String.t(),
          can_view: boolean,
          can_run_workflows: boolean,
          can_view_logs: boolean
        }
  defstruct [:project_id, :org_id, :can_view, :can_run_workflows, :can_view_logs]

  field(:project_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:can_view, 3, type: :bool)
  field(:can_run_workflows, 4, type: :bool)
  field(:can_view_logs, 5, type: :bool)
end

defmodule InternalApi.McpGrant.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          client_id: String.t(),
          client_name: String.t(),
          tool_scopes: [String.t()],
          org_grants: [InternalApi.McpGrant.OrgGrantInput.t()],
          project_grants: [InternalApi.McpGrant.ProjectGrantInput.t()],
          expires_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :user_id,
    :client_id,
    :client_name,
    :tool_scopes,
    :org_grants,
    :project_grants,
    :expires_at
  ]

  field(:user_id, 1, type: :string)
  field(:client_id, 2, type: :string)
  field(:client_name, 3, type: :string)
  field(:tool_scopes, 4, repeated: true, type: :string)
  field(:org_grants, 5, repeated: true, type: InternalApi.McpGrant.OrgGrantInput)
  field(:project_grants, 6, repeated: true, type: InternalApi.McpGrant.ProjectGrantInput)
  field(:expires_at, 7, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.McpGrant.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant: InternalApi.McpGrant.McpGrant.t()
        }
  defstruct [:grant]

  field(:grant, 1, type: InternalApi.McpGrant.McpGrant)
end

defmodule InternalApi.McpGrant.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          page_size: integer,
          page_token: String.t(),
          include_revoked: boolean
        }
  defstruct [:user_id, :page_size, :page_token, :include_revoked]

  field(:user_id, 1, type: :string)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
  field(:include_revoked, 4, type: :bool)
end

defmodule InternalApi.McpGrant.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grants: [InternalApi.McpGrant.McpGrant.t()],
          next_page_token: String.t(),
          total_count: integer
        }
  defstruct [:grants, :next_page_token, :total_count]

  field(:grants, 1, repeated: true, type: InternalApi.McpGrant.McpGrant)
  field(:next_page_token, 2, type: :string)
  field(:total_count, 3, type: :int32)
end

defmodule InternalApi.McpGrant.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t()
        }
  defstruct [:grant_id]

  field(:grant_id, 1, type: :string)
end

defmodule InternalApi.McpGrant.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant: InternalApi.McpGrant.McpGrant.t()
        }
  defstruct [:grant]

  field(:grant, 1, type: InternalApi.McpGrant.McpGrant)
end

defmodule InternalApi.McpGrant.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t(),
          user_id: String.t(),
          tool_scopes: [String.t()],
          org_grants: [InternalApi.McpGrant.OrgGrantInput.t()],
          project_grants: [InternalApi.McpGrant.ProjectGrantInput.t()]
        }
  defstruct [:grant_id, :user_id, :tool_scopes, :org_grants, :project_grants]

  field(:grant_id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:tool_scopes, 3, repeated: true, type: :string)
  field(:org_grants, 4, repeated: true, type: InternalApi.McpGrant.OrgGrantInput)
  field(:project_grants, 5, repeated: true, type: InternalApi.McpGrant.ProjectGrantInput)
end

defmodule InternalApi.McpGrant.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant: InternalApi.McpGrant.McpGrant.t()
        }
  defstruct [:grant]

  field(:grant, 1, type: InternalApi.McpGrant.McpGrant)
end

defmodule InternalApi.McpGrant.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t(),
          user_id: String.t()
        }
  defstruct [:grant_id, :user_id]

  field(:grant_id, 1, type: :string)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.McpGrant.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.McpGrant.RevokeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t(),
          user_id: String.t()
        }
  defstruct [:grant_id, :user_id]

  field(:grant_id, 1, type: :string)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.McpGrant.RevokeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant: InternalApi.McpGrant.McpGrant.t()
        }
  defstruct [:grant]

  field(:grant, 1, type: InternalApi.McpGrant.McpGrant)
end

defmodule InternalApi.McpGrant.CheckOrgAccessRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t(),
          org_id: String.t()
        }
  defstruct [:grant_id, :org_id]

  field(:grant_id, 1, type: :string)
  field(:org_id, 2, type: :string)
end

defmodule InternalApi.McpGrant.CheckOrgAccessResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed: boolean,
          can_view: boolean,
          can_run_workflows: boolean
        }
  defstruct [:allowed, :can_view, :can_run_workflows]

  field(:allowed, 1, type: :bool)
  field(:can_view, 2, type: :bool)
  field(:can_run_workflows, 3, type: :bool)
end

defmodule InternalApi.McpGrant.CheckProjectAccessRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t(),
          project_id: String.t()
        }
  defstruct [:grant_id, :project_id]

  field(:grant_id, 1, type: :string)
  field(:project_id, 2, type: :string)
end

defmodule InternalApi.McpGrant.CheckProjectAccessResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed: boolean,
          can_view: boolean,
          can_run_workflows: boolean,
          can_view_logs: boolean
        }
  defstruct [:allowed, :can_view, :can_run_workflows, :can_view_logs]

  field(:allowed, 1, type: :bool)
  field(:can_view, 2, type: :bool)
  field(:can_run_workflows, 3, type: :bool)
  field(:can_view_logs, 4, type: :bool)
end

defmodule InternalApi.McpGrant.GetGrantRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t()
        }
  defstruct [:grant_id]

  field(:grant_id, 1, type: :string)
end

defmodule InternalApi.McpGrant.GetGrantResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant: InternalApi.McpGrant.McpGrant.t(),
          is_valid: boolean
        }
  defstruct [:grant, :is_valid]

  field(:grant, 1, type: InternalApi.McpGrant.McpGrant)
  field(:is_valid, 2, type: :bool)
end

defmodule InternalApi.McpGrant.FindExistingGrantRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          client_id: String.t()
        }
  defstruct [:user_id, :client_id]

  field(:user_id, 1, type: :string)
  field(:client_id, 2, type: :string)
end

defmodule InternalApi.McpGrant.FindExistingGrantResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant: InternalApi.McpGrant.McpGrant.t(),
          found: boolean
        }
  defstruct [:grant, :found]

  field(:grant, 1, type: InternalApi.McpGrant.McpGrant)
  field(:found, 2, type: :bool)
end

defmodule InternalApi.McpGrant.ConsentChallenge do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          client_id: String.t(),
          client_name: String.t(),
          redirect_uri: String.t(),
          code_challenge: String.t(),
          code_challenge_method: String.t(),
          state: String.t(),
          requested_scope: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          expires_at: Google.Protobuf.Timestamp.t(),
          consumed_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :id,
    :user_id,
    :client_id,
    :client_name,
    :redirect_uri,
    :code_challenge,
    :code_challenge_method,
    :state,
    :requested_scope,
    :created_at,
    :expires_at,
    :consumed_at
  ]

  field(:id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:client_id, 3, type: :string)
  field(:client_name, 4, type: :string)
  field(:redirect_uri, 5, type: :string)
  field(:code_challenge, 6, type: :string)
  field(:code_challenge_method, 7, type: :string)
  field(:state, 8, type: :string)
  field(:requested_scope, 9, type: :string)
  field(:created_at, 10, type: Google.Protobuf.Timestamp)
  field(:expires_at, 11, type: Google.Protobuf.Timestamp)
  field(:consumed_at, 12, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.McpGrant.GrantSelection do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          tool_scopes: [String.t()],
          org_grants: [InternalApi.McpGrant.OrgGrantInput.t()],
          project_grants: [InternalApi.McpGrant.ProjectGrantInput.t()]
        }
  defstruct [:tool_scopes, :org_grants, :project_grants]

  field(:tool_scopes, 1, repeated: true, type: :string)
  field(:org_grants, 2, repeated: true, type: InternalApi.McpGrant.OrgGrantInput)
  field(:project_grants, 3, repeated: true, type: InternalApi.McpGrant.ProjectGrantInput)
end

defmodule InternalApi.McpGrant.GrantableOrganization do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          org_name: String.t(),
          can_view: boolean,
          can_run_workflows: boolean
        }
  defstruct [:org_id, :org_name, :can_view, :can_run_workflows]

  field(:org_id, 1, type: :string)
  field(:org_name, 2, type: :string)
  field(:can_view, 3, type: :bool)
  field(:can_run_workflows, 4, type: :bool)
end

defmodule InternalApi.McpGrant.GrantableProject do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          org_id: String.t(),
          org_name: String.t(),
          project_name: String.t(),
          can_view: boolean,
          can_run_workflows: boolean,
          can_view_logs: boolean
        }
  defstruct [
    :project_id,
    :org_id,
    :org_name,
    :project_name,
    :can_view,
    :can_run_workflows,
    :can_view_logs
  ]

  field(:project_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:org_name, 3, type: :string)
  field(:project_name, 4, type: :string)
  field(:can_view, 5, type: :bool)
  field(:can_run_workflows, 6, type: :bool)
  field(:can_view_logs, 7, type: :bool)
end

defmodule InternalApi.McpGrant.CreateConsentChallengeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          client_id: String.t(),
          client_name: String.t(),
          redirect_uri: String.t(),
          code_challenge: String.t(),
          code_challenge_method: String.t(),
          state: String.t(),
          requested_scope: String.t()
        }
  defstruct [
    :user_id,
    :client_id,
    :client_name,
    :redirect_uri,
    :code_challenge,
    :code_challenge_method,
    :state,
    :requested_scope
  ]

  field(:user_id, 1, type: :string)
  field(:client_id, 2, type: :string)
  field(:client_name, 3, type: :string)
  field(:redirect_uri, 4, type: :string)
  field(:code_challenge, 5, type: :string)
  field(:code_challenge_method, 6, type: :string)
  field(:state, 7, type: :string)
  field(:requested_scope, 8, type: :string)
end

defmodule InternalApi.McpGrant.CreateConsentChallengeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          challenge_id: String.t(),
          expires_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:challenge_id, :expires_at]

  field(:challenge_id, 1, type: :string)
  field(:expires_at, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.McpGrant.DescribeConsentChallengeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          challenge_id: String.t(),
          user_id: String.t()
        }
  defstruct [:challenge_id, :user_id]

  field(:challenge_id, 1, type: :string)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.McpGrant.DescribeConsentChallengeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          challenge: InternalApi.McpGrant.ConsentChallenge.t(),
          found_existing_grant: boolean,
          existing_grant: InternalApi.McpGrant.McpGrant.t(),
          default_selection: InternalApi.McpGrant.GrantSelection.t(),
          available_organizations: [InternalApi.McpGrant.GrantableOrganization.t()],
          available_projects: [InternalApi.McpGrant.GrantableProject.t()]
        }
  defstruct [
    :challenge,
    :found_existing_grant,
    :existing_grant,
    :default_selection,
    :available_organizations,
    :available_projects
  ]

  field(:challenge, 1, type: InternalApi.McpGrant.ConsentChallenge)
  field(:found_existing_grant, 2, type: :bool)
  field(:existing_grant, 3, type: InternalApi.McpGrant.McpGrant)
  field(:default_selection, 4, type: InternalApi.McpGrant.GrantSelection)

  field(:available_organizations, 5,
    repeated: true,
    type: InternalApi.McpGrant.GrantableOrganization
  )

  field(:available_projects, 6, repeated: true, type: InternalApi.McpGrant.GrantableProject)
end

defmodule InternalApi.McpGrant.ApproveConsentChallengeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          challenge_id: String.t(),
          user_id: String.t(),
          selection: InternalApi.McpGrant.GrantSelection.t()
        }
  defstruct [:challenge_id, :user_id, :selection]

  field(:challenge_id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:selection, 3, type: InternalApi.McpGrant.GrantSelection)
end

defmodule InternalApi.McpGrant.ApproveConsentChallengeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t(),
          authorization_code: String.t(),
          redirect_uri: String.t(),
          state: String.t(),
          redirect_url: String.t(),
          reused_existing_grant: boolean
        }
  defstruct [
    :grant_id,
    :authorization_code,
    :redirect_uri,
    :state,
    :redirect_url,
    :reused_existing_grant
  ]

  field(:grant_id, 1, type: :string)
  field(:authorization_code, 2, type: :string)
  field(:redirect_uri, 3, type: :string)
  field(:state, 4, type: :string)
  field(:redirect_url, 5, type: :string)
  field(:reused_existing_grant, 6, type: :bool)
end

defmodule InternalApi.McpGrant.DenyConsentChallengeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          challenge_id: String.t(),
          user_id: String.t(),
          error: String.t(),
          error_description: String.t()
        }
  defstruct [:challenge_id, :user_id, :error, :error_description]

  field(:challenge_id, 1, type: :string)
  field(:user_id, 2, type: :string)
  field(:error, 3, type: :string)
  field(:error_description, 4, type: :string)
end

defmodule InternalApi.McpGrant.DenyConsentChallengeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          redirect_uri: String.t(),
          state: String.t(),
          redirect_url: String.t()
        }
  defstruct [:redirect_uri, :state, :redirect_url]

  field(:redirect_uri, 1, type: :string)
  field(:state, 2, type: :string)
  field(:redirect_url, 3, type: :string)
end

defmodule InternalApi.McpGrant.ResolveGrantForAuthRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          grant_id: String.t(),
          user_id: String.t()
        }
  defstruct [:grant_id, :user_id]

  field(:grant_id, 1, type: :string)
  field(:user_id, 2, type: :string)
end

defmodule InternalApi.McpGrant.ResolvedOrgPermissions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          permissions: [String.t()]
        }
  defstruct [:org_id, :permissions]

  field(:org_id, 1, type: :string)
  field(:permissions, 2, repeated: true, type: :string)
end

defmodule InternalApi.McpGrant.ResolvedProjectPermissions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          org_id: String.t(),
          permissions: [String.t()]
        }
  defstruct [:project_id, :org_id, :permissions]

  field(:project_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:permissions, 3, repeated: true, type: :string)
end

defmodule InternalApi.McpGrant.ResolveGrantForAuthResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          valid: boolean,
          invalid_reason: String.t(),
          grant: InternalApi.McpGrant.McpGrant.t(),
          tool_scopes: [String.t()],
          org_permissions: [InternalApi.McpGrant.ResolvedOrgPermissions.t()],
          project_permissions: [InternalApi.McpGrant.ResolvedProjectPermissions.t()]
        }
  defstruct [
    :valid,
    :invalid_reason,
    :grant,
    :tool_scopes,
    :org_permissions,
    :project_permissions
  ]

  field(:valid, 1, type: :bool)
  field(:invalid_reason, 2, type: :string)
  field(:grant, 3, type: InternalApi.McpGrant.McpGrant)
  field(:tool_scopes, 4, repeated: true, type: :string)
  field(:org_permissions, 5, repeated: true, type: InternalApi.McpGrant.ResolvedOrgPermissions)

  field(:project_permissions, 6,
    repeated: true,
    type: InternalApi.McpGrant.ResolvedProjectPermissions
  )
end

defmodule InternalApi.McpGrant.McpGrantService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.McpGrant.McpGrantService"

  rpc(:Create, InternalApi.McpGrant.CreateRequest, InternalApi.McpGrant.CreateResponse)
  rpc(:List, InternalApi.McpGrant.ListRequest, InternalApi.McpGrant.ListResponse)
  rpc(:Describe, InternalApi.McpGrant.DescribeRequest, InternalApi.McpGrant.DescribeResponse)
  rpc(:Update, InternalApi.McpGrant.UpdateRequest, InternalApi.McpGrant.UpdateResponse)
  rpc(:Delete, InternalApi.McpGrant.DeleteRequest, InternalApi.McpGrant.DeleteResponse)
  rpc(:Revoke, InternalApi.McpGrant.RevokeRequest, InternalApi.McpGrant.RevokeResponse)

  rpc(
    :CheckOrgAccess,
    InternalApi.McpGrant.CheckOrgAccessRequest,
    InternalApi.McpGrant.CheckOrgAccessResponse
  )

  rpc(
    :CheckProjectAccess,
    InternalApi.McpGrant.CheckProjectAccessRequest,
    InternalApi.McpGrant.CheckProjectAccessResponse
  )

  rpc(:GetGrant, InternalApi.McpGrant.GetGrantRequest, InternalApi.McpGrant.GetGrantResponse)

  rpc(
    :FindExistingGrant,
    InternalApi.McpGrant.FindExistingGrantRequest,
    InternalApi.McpGrant.FindExistingGrantResponse
  )

  rpc(
    :CreateConsentChallenge,
    InternalApi.McpGrant.CreateConsentChallengeRequest,
    InternalApi.McpGrant.CreateConsentChallengeResponse
  )

  rpc(
    :DescribeConsentChallenge,
    InternalApi.McpGrant.DescribeConsentChallengeRequest,
    InternalApi.McpGrant.DescribeConsentChallengeResponse
  )

  rpc(
    :ApproveConsentChallenge,
    InternalApi.McpGrant.ApproveConsentChallengeRequest,
    InternalApi.McpGrant.ApproveConsentChallengeResponse
  )

  rpc(
    :DenyConsentChallenge,
    InternalApi.McpGrant.DenyConsentChallengeRequest,
    InternalApi.McpGrant.DenyConsentChallengeResponse
  )

  rpc(
    :ResolveGrantForAuth,
    InternalApi.McpGrant.ResolveGrantForAuthRequest,
    InternalApi.McpGrant.ResolveGrantForAuthResponse
  )
end

defmodule InternalApi.McpGrant.McpGrantService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.McpGrant.McpGrantService.Service
end
