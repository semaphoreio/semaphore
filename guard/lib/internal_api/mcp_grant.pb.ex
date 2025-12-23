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
end

defmodule InternalApi.McpGrant.McpGrantService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.McpGrant.McpGrantService.Service
end
