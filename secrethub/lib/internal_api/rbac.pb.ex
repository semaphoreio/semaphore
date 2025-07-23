defmodule InternalApi.RBAC.SubjectType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :USER | :GROUP

  field :USER, 0

  field :GROUP, 1
end

defmodule InternalApi.RBAC.Scope do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :SCOPE_UNSPECIFIED | :SCOPE_ORG | :SCOPE_PROJECT

  field :SCOPE_UNSPECIFIED, 0

  field :SCOPE_ORG, 1

  field :SCOPE_PROJECT, 2
end

defmodule InternalApi.RBAC.RoleBindingSource do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t ::
          integer
          | :ROLE_BINDING_SOURCE_UNSPECIFIED
          | :ROLE_BINDING_SOURCE_MANUALLY
          | :ROLE_BINDING_SOURCE_GITHUB
          | :ROLE_BINDING_SOURCE_BITBUCKET
          | :ROLE_BINDING_SOURCE_GITLAB
          | :ROLE_BINDING_SOURCE_SCIM
          | :ROLE_BINDING_SOURCE_INHERITED_FROM_ORG_ROLE
          | :ROLE_BINDING_SOURCE_SAML_JIT

  field :ROLE_BINDING_SOURCE_UNSPECIFIED, 0

  field :ROLE_BINDING_SOURCE_MANUALLY, 1

  field :ROLE_BINDING_SOURCE_GITHUB, 2

  field :ROLE_BINDING_SOURCE_BITBUCKET, 3

  field :ROLE_BINDING_SOURCE_GITLAB, 4

  field :ROLE_BINDING_SOURCE_SCIM, 5

  field :ROLE_BINDING_SOURCE_INHERITED_FROM_ORG_ROLE, 6

  field :ROLE_BINDING_SOURCE_SAML_JIT, 7
end

defmodule InternalApi.RBAC.ListUserPermissionsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t(),
          project_id: String.t()
        }

  defstruct [:user_id, :org_id, :project_id]

  field :user_id, 1, type: :string
  field :org_id, 2, type: :string
  field :project_id, 3, type: :string
end

defmodule InternalApi.RBAC.ListUserPermissionsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          org_id: String.t(),
          project_id: String.t(),
          permissions: [String.t()]
        }

  defstruct [:user_id, :org_id, :project_id, :permissions]

  field :user_id, 1, type: :string
  field :org_id, 2, type: :string
  field :project_id, 3, type: :string
  field :permissions, 4, repeated: true, type: :string
end

defmodule InternalApi.RBAC.ListExistingPermissionsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          scope: InternalApi.RBAC.Scope.t()
        }

  defstruct [:scope]

  field :scope, 1, type: InternalApi.RBAC.Scope, enum: true
end

defmodule InternalApi.RBAC.ListExistingPermissionsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          permissions: [InternalApi.RBAC.Permission.t()]
        }

  defstruct [:permissions]

  field :permissions, 1, repeated: true, type: InternalApi.RBAC.Permission
end

defmodule InternalApi.RBAC.AssignRoleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role_assignment: InternalApi.RBAC.RoleAssignment.t() | nil,
          requester_id: String.t()
        }

  defstruct [:role_assignment, :requester_id]

  field :role_assignment, 1, type: InternalApi.RBAC.RoleAssignment
  field :requester_id, 2, type: :string
end

defmodule InternalApi.RBAC.AssignRoleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.RBAC.RetractRoleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role_assignment: InternalApi.RBAC.RoleAssignment.t() | nil,
          requester_id: String.t()
        }

  defstruct [:role_assignment, :requester_id]

  field :role_assignment, 1, type: InternalApi.RBAC.RoleAssignment
  field :requester_id, 2, type: :string
end

defmodule InternalApi.RBAC.RetractRoleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.RBAC.SubjectsHaveRolesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role_assignments: [InternalApi.RBAC.RoleAssignment.t()]
        }

  defstruct [:role_assignments]

  field :role_assignments, 1, repeated: true, type: InternalApi.RBAC.RoleAssignment
end

defmodule InternalApi.RBAC.SubjectsHaveRolesResponse.HasRole do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role_assignment: InternalApi.RBAC.RoleAssignment.t() | nil,
          has_role: boolean
        }

  defstruct [:role_assignment, :has_role]

  field :role_assignment, 1, type: InternalApi.RBAC.RoleAssignment
  field :has_role, 2, type: :bool
end

defmodule InternalApi.RBAC.SubjectsHaveRolesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          has_roles: [InternalApi.RBAC.SubjectsHaveRolesResponse.HasRole.t()]
        }

  defstruct [:has_roles]

  field :has_roles, 1, repeated: true, type: InternalApi.RBAC.SubjectsHaveRolesResponse.HasRole
end

defmodule InternalApi.RBAC.ListRolesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          scope: InternalApi.RBAC.Scope.t()
        }

  defstruct [:org_id, :scope]

  field :org_id, 1, type: :string
  field :scope, 2, type: InternalApi.RBAC.Scope, enum: true
end

defmodule InternalApi.RBAC.ListRolesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          roles: [InternalApi.RBAC.Role.t()]
        }

  defstruct [:roles]

  field :roles, 1, repeated: true, type: InternalApi.RBAC.Role
end

defmodule InternalApi.RBAC.DescribeRoleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          role_id: String.t()
        }

  defstruct [:org_id, :role_id]

  field :org_id, 1, type: :string
  field :role_id, 2, type: :string
end

defmodule InternalApi.RBAC.DescribeRoleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role: InternalApi.RBAC.Role.t() | nil
        }

  defstruct [:role]

  field :role, 1, type: InternalApi.RBAC.Role
end

defmodule InternalApi.RBAC.ModifyRoleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role: InternalApi.RBAC.Role.t() | nil,
          requester_id: String.t()
        }

  defstruct [:role, :requester_id]

  field :role, 1, type: InternalApi.RBAC.Role
  field :requester_id, 2, type: :string
end

defmodule InternalApi.RBAC.ModifyRoleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role: InternalApi.RBAC.Role.t() | nil
        }

  defstruct [:role]

  field :role, 1, type: InternalApi.RBAC.Role
end

defmodule InternalApi.RBAC.DestroyRoleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          role_id: String.t(),
          requester_id: String.t()
        }

  defstruct [:org_id, :role_id, :requester_id]

  field :org_id, 1, type: :string
  field :role_id, 2, type: :string
  field :requester_id, 3, type: :string
end

defmodule InternalApi.RBAC.DestroyRoleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role_id: String.t()
        }

  defstruct [:role_id]

  field :role_id, 1, type: :string
end

defmodule InternalApi.RBAC.ListMembersRequest.Page do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_no: integer,
          page_size: integer
        }

  defstruct [:page_no, :page_size]

  field :page_no, 1, type: :int32
  field :page_size, 2, type: :int32
end

defmodule InternalApi.RBAC.ListMembersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          member_name_contains: String.t(),
          page: InternalApi.RBAC.ListMembersRequest.Page.t() | nil,
          member_has_role: String.t(),
          member_type: InternalApi.RBAC.SubjectType.t()
        }

  defstruct [:org_id, :project_id, :member_name_contains, :page, :member_has_role, :member_type]

  field :org_id, 1, type: :string
  field :project_id, 2, type: :string
  field :member_name_contains, 3, type: :string
  field :page, 4, type: InternalApi.RBAC.ListMembersRequest.Page
  field :member_has_role, 5, type: :string
  field :member_type, 6, type: InternalApi.RBAC.SubjectType, enum: true
end

defmodule InternalApi.RBAC.ListMembersResponse.Member do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          subject: InternalApi.RBAC.Subject.t() | nil,
          subject_role_bindings: [InternalApi.RBAC.SubjectRoleBinding.t()]
        }

  defstruct [:subject, :subject_role_bindings]

  field :subject, 1, type: InternalApi.RBAC.Subject
  field :subject_role_bindings, 3, repeated: true, type: InternalApi.RBAC.SubjectRoleBinding
end

defmodule InternalApi.RBAC.ListMembersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          members: [InternalApi.RBAC.ListMembersResponse.Member.t()],
          total_pages: integer
        }

  defstruct [:members, :total_pages]

  field :members, 1, repeated: true, type: InternalApi.RBAC.ListMembersResponse.Member
  field :total_pages, 2, type: :int32
end

defmodule InternalApi.RBAC.CountMembersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.RBAC.CountMembersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          members: integer
        }

  defstruct [:members]

  field :members, 1, type: :int32
end

defmodule InternalApi.RBAC.SubjectRoleBinding do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role: InternalApi.RBAC.Role.t() | nil,
          source: InternalApi.RBAC.RoleBindingSource.t(),
          role_assigned_at: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:role, :source, :role_assigned_at]

  field :role, 1, type: InternalApi.RBAC.Role
  field :source, 2, type: InternalApi.RBAC.RoleBindingSource, enum: true
  field :role_assigned_at, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.RBAC.ListAccessibleOrgsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t()
        }

  defstruct [:user_id]

  field :user_id, 1, type: :string
end

defmodule InternalApi.RBAC.ListAccessibleOrgsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_ids: [String.t()]
        }

  defstruct [:org_ids]

  field :org_ids, 1, repeated: true, type: :string
end

defmodule InternalApi.RBAC.ListAccessibleProjectsRequest do
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

defmodule InternalApi.RBAC.ListAccessibleProjectsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_ids: [String.t()]
        }

  defstruct [:project_ids]

  field :project_ids, 1, repeated: true, type: :string
end

defmodule InternalApi.RBAC.RoleAssignment do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          role_id: String.t(),
          subject: InternalApi.RBAC.Subject.t() | nil,
          org_id: String.t(),
          project_id: String.t()
        }

  defstruct [:role_id, :subject, :org_id, :project_id]

  field :role_id, 1, type: :string
  field :subject, 2, type: InternalApi.RBAC.Subject
  field :org_id, 3, type: :string
  field :project_id, 4, type: :string
end

defmodule InternalApi.RBAC.Subject do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          subject_type: InternalApi.RBAC.SubjectType.t(),
          subject_id: String.t(),
          display_name: String.t()
        }

  defstruct [:subject_type, :subject_id, :display_name]

  field :subject_type, 1, type: InternalApi.RBAC.SubjectType, enum: true
  field :subject_id, 2, type: :string
  field :display_name, 3, type: :string
end

defmodule InternalApi.RBAC.RefreshCollaboratorsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t()
        }

  defstruct [:org_id]

  field :org_id, 1, type: :string
end

defmodule InternalApi.RBAC.RefreshCollaboratorsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.RBAC.Role do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          org_id: String.t(),
          scope: InternalApi.RBAC.Scope.t(),
          description: String.t(),
          permissions: [String.t()],
          rbac_permissions: [InternalApi.RBAC.Permission.t()],
          inherited_role: InternalApi.RBAC.Role.t() | nil,
          maps_to: InternalApi.RBAC.Role.t() | nil,
          readonly: boolean
        }

  defstruct [
    :id,
    :name,
    :org_id,
    :scope,
    :description,
    :permissions,
    :rbac_permissions,
    :inherited_role,
    :maps_to,
    :readonly
  ]

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :org_id, 3, type: :string
  field :scope, 4, type: InternalApi.RBAC.Scope, enum: true
  field :description, 5, type: :string
  field :permissions, 6, repeated: true, type: :string
  field :rbac_permissions, 7, repeated: true, type: InternalApi.RBAC.Permission
  field :inherited_role, 8, type: InternalApi.RBAC.Role
  field :maps_to, 9, type: InternalApi.RBAC.Role
  field :readonly, 10, type: :bool
end

defmodule InternalApi.RBAC.Permission do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          scope: InternalApi.RBAC.Scope.t()
        }

  defstruct [:id, :name, :description, :scope]

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :description, 3, type: :string
  field :scope, 4, type: InternalApi.RBAC.Scope, enum: true
end

defmodule InternalApi.RBAC.RBAC.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.RBAC.RBAC"

  rpc(
    :ListUserPermissions,
    InternalApi.RBAC.ListUserPermissionsRequest,
    InternalApi.RBAC.ListUserPermissionsResponse
  )

  rpc(
    :ListExistingPermissions,
    InternalApi.RBAC.ListExistingPermissionsRequest,
    InternalApi.RBAC.ListExistingPermissionsResponse
  )

  rpc(:AssignRole, InternalApi.RBAC.AssignRoleRequest, InternalApi.RBAC.AssignRoleResponse)

  rpc(:RetractRole, InternalApi.RBAC.RetractRoleRequest, InternalApi.RBAC.RetractRoleResponse)

  rpc(
    :SubjectsHaveRoles,
    InternalApi.RBAC.SubjectsHaveRolesRequest,
    InternalApi.RBAC.SubjectsHaveRolesResponse
  )

  rpc(:ListRoles, InternalApi.RBAC.ListRolesRequest, InternalApi.RBAC.ListRolesResponse)

  rpc(:DescribeRole, InternalApi.RBAC.DescribeRoleRequest, InternalApi.RBAC.DescribeRoleResponse)

  rpc(:ModifyRole, InternalApi.RBAC.ModifyRoleRequest, InternalApi.RBAC.ModifyRoleResponse)

  rpc(:DestroyRole, InternalApi.RBAC.DestroyRoleRequest, InternalApi.RBAC.DestroyRoleResponse)

  rpc(:ListMembers, InternalApi.RBAC.ListMembersRequest, InternalApi.RBAC.ListMembersResponse)

  rpc(:CountMembers, InternalApi.RBAC.CountMembersRequest, InternalApi.RBAC.CountMembersResponse)

  rpc(
    :ListAccessibleOrgs,
    InternalApi.RBAC.ListAccessibleOrgsRequest,
    InternalApi.RBAC.ListAccessibleOrgsResponse
  )

  rpc(
    :ListAccessibleProjects,
    InternalApi.RBAC.ListAccessibleProjectsRequest,
    InternalApi.RBAC.ListAccessibleProjectsResponse
  )

  rpc(
    :RefreshCollaborators,
    InternalApi.RBAC.RefreshCollaboratorsRequest,
    InternalApi.RBAC.RefreshCollaboratorsResponse
  )
end

defmodule InternalApi.RBAC.RBAC.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.RBAC.RBAC.Service
end
