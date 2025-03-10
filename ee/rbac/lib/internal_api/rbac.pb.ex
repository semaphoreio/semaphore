defmodule InternalApi.RBAC.SubjectType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:USER, 0)
  field(:GROUP, 1)
end

defmodule InternalApi.RBAC.Scope do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:SCOPE_UNSPECIFIED, 0)
  field(:SCOPE_ORG, 1)
  field(:SCOPE_PROJECT, 2)
end

defmodule InternalApi.RBAC.RoleBindingSource do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:ROLE_BINDING_SOURCE_UNSPECIFIED, 0)
  field(:ROLE_BINDING_SOURCE_MANUALLY, 1)
  field(:ROLE_BINDING_SOURCE_GITHUB, 2)
  field(:ROLE_BINDING_SOURCE_BITBUCKET, 3)
  field(:ROLE_BINDING_SOURCE_GITLAB, 4)
  field(:ROLE_BINDING_SOURCE_SCIM, 5)
  field(:ROLE_BINDING_SOURCE_INHERITED_FROM_ORG_ROLE, 6)
  field(:ROLE_BINDING_SOURCE_SAML_JIT, 7)
end

defmodule InternalApi.RBAC.ListUserPermissionsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:project_id, 3, type: :string, json_name: "projectId")
end

defmodule InternalApi.RBAC.ListUserPermissionsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:project_id, 3, type: :string, json_name: "projectId")
  field(:permissions, 4, repeated: true, type: :string)
end

defmodule InternalApi.RBAC.ListExistingPermissionsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:scope, 1, type: InternalApi.RBAC.Scope, enum: true)
end

defmodule InternalApi.RBAC.ListExistingPermissionsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:permissions, 1, repeated: true, type: InternalApi.RBAC.Permission)
end

defmodule InternalApi.RBAC.AssignRoleRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role_assignment, 1, type: InternalApi.RBAC.RoleAssignment, json_name: "roleAssignment")
  field(:requester_id, 2, type: :string, json_name: "requesterId")
end

defmodule InternalApi.RBAC.AssignRoleResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.RBAC.RetractRoleRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role_assignment, 1, type: InternalApi.RBAC.RoleAssignment, json_name: "roleAssignment")
  field(:requester_id, 2, type: :string, json_name: "requesterId")
end

defmodule InternalApi.RBAC.RetractRoleResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.RBAC.SubjectsHaveRolesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role_assignments, 1,
    repeated: true,
    type: InternalApi.RBAC.RoleAssignment,
    json_name: "roleAssignments"
  )
end

defmodule InternalApi.RBAC.SubjectsHaveRolesResponse.HasRole do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role_assignment, 1, type: InternalApi.RBAC.RoleAssignment, json_name: "roleAssignment")
  field(:has_role, 2, type: :bool, json_name: "hasRole")
end

defmodule InternalApi.RBAC.SubjectsHaveRolesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:has_roles, 1,
    repeated: true,
    type: InternalApi.RBAC.SubjectsHaveRolesResponse.HasRole,
    json_name: "hasRoles"
  )
end

defmodule InternalApi.RBAC.ListRolesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:scope, 2, type: InternalApi.RBAC.Scope, enum: true)
end

defmodule InternalApi.RBAC.ListRolesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:roles, 1, repeated: true, type: InternalApi.RBAC.Role)
end

defmodule InternalApi.RBAC.DescribeRoleRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:role_id, 2, type: :string, json_name: "roleId")
end

defmodule InternalApi.RBAC.DescribeRoleResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role, 1, type: InternalApi.RBAC.Role)
end

defmodule InternalApi.RBAC.ModifyRoleRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role, 1, type: InternalApi.RBAC.Role)
  field(:requester_id, 2, type: :string, json_name: "requesterId")
end

defmodule InternalApi.RBAC.ModifyRoleResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role, 1, type: InternalApi.RBAC.Role)
end

defmodule InternalApi.RBAC.DestroyRoleRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:role_id, 2, type: :string, json_name: "roleId")
  field(:requester_id, 3, type: :string, json_name: "requesterId")
end

defmodule InternalApi.RBAC.DestroyRoleResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role_id, 1, type: :string, json_name: "roleId")
end

defmodule InternalApi.RBAC.ListMembersRequest.Page do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:page_no, 1, type: :int32, json_name: "pageNo")
  field(:page_size, 2, type: :int32, json_name: "pageSize")
end

defmodule InternalApi.RBAC.ListMembersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:member_name_contains, 3, type: :string, json_name: "memberNameContains")
  field(:page, 4, type: InternalApi.RBAC.ListMembersRequest.Page)
  field(:member_has_role, 5, type: :string, json_name: "memberHasRole")
  field(:member_type, 6, type: InternalApi.RBAC.SubjectType, json_name: "memberType", enum: true)
end

defmodule InternalApi.RBAC.ListMembersResponse.Member do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:subject, 1, type: InternalApi.RBAC.Subject)

  field(:subject_role_bindings, 3,
    repeated: true,
    type: InternalApi.RBAC.SubjectRoleBinding,
    json_name: "subjectRoleBindings"
  )
end

defmodule InternalApi.RBAC.ListMembersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:members, 1, repeated: true, type: InternalApi.RBAC.ListMembersResponse.Member)
  field(:total_pages, 2, type: :int32, json_name: "totalPages")
end

defmodule InternalApi.RBAC.CountMembersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.RBAC.CountMembersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:members, 1, type: :int32)
end

defmodule InternalApi.RBAC.SubjectRoleBinding do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role, 1, type: InternalApi.RBAC.Role)
  field(:source, 2, type: InternalApi.RBAC.RoleBindingSource, enum: true)
  field(:role_assigned_at, 3, type: Google.Protobuf.Timestamp, json_name: "roleAssignedAt")
end

defmodule InternalApi.RBAC.ListAccessibleOrgsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
end

defmodule InternalApi.RBAC.ListAccessibleOrgsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_ids, 1, repeated: true, type: :string, json_name: "orgIds")
end

defmodule InternalApi.RBAC.ListAccessibleProjectsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:org_id, 2, type: :string, json_name: "orgId")
end

defmodule InternalApi.RBAC.ListAccessibleProjectsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_ids, 1, repeated: true, type: :string, json_name: "projectIds")
end

defmodule InternalApi.RBAC.RoleAssignment do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:role_id, 1, type: :string, json_name: "roleId")
  field(:subject, 2, type: InternalApi.RBAC.Subject)
  field(:org_id, 3, type: :string, json_name: "orgId")
  field(:project_id, 4, type: :string, json_name: "projectId")
end

defmodule InternalApi.RBAC.Subject do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:subject_type, 1,
    type: InternalApi.RBAC.SubjectType,
    json_name: "subjectType",
    enum: true
  )

  field(:subject_id, 2, type: :string, json_name: "subjectId")
  field(:display_name, 3, type: :string, json_name: "displayName")
end

defmodule InternalApi.RBAC.RefreshCollaboratorsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
end

defmodule InternalApi.RBAC.RefreshCollaboratorsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.RBAC.Role do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:org_id, 3, type: :string, json_name: "orgId")
  field(:scope, 4, type: InternalApi.RBAC.Scope, enum: true)
  field(:description, 5, type: :string)
  field(:permissions, 6, repeated: true, type: :string)

  field(:rbac_permissions, 7,
    repeated: true,
    type: InternalApi.RBAC.Permission,
    json_name: "rbacPermissions"
  )

  field(:inherited_role, 8, type: InternalApi.RBAC.Role, json_name: "inheritedRole")
  field(:maps_to, 9, type: InternalApi.RBAC.Role, json_name: "mapsTo")
  field(:readonly, 10, type: :bool)
end

defmodule InternalApi.RBAC.Permission do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:description, 3, type: :string)
  field(:scope, 4, type: InternalApi.RBAC.Scope, enum: true)
end

defmodule InternalApi.RBAC.RBAC.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.RBAC.RBAC", protoc_gen_elixir_version: "0.13.0"

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
