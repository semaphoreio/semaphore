# RBAC Service

Role-Based Access Control (RBAC) service for Semaphore CI/CD platform.

## Database Schema

### Core RBAC System

```mermaid
erDiagram
    scopes ||--o{ permissions : has
    scopes ||--o{ rbac_roles : has

    permissions ||--o{ role_permission_bindings : ""
    rbac_roles ||--o{ role_permission_bindings : ""

    rbac_roles ||--o{ role_inheritance : inheriting
    rbac_roles ||--o{ role_inheritance : inherited

    rbac_roles ||--o{ subject_role_bindings : ""
    subjects ||--o{ subject_role_bindings : ""

    scopes {
        int id
        string scope_name
    }

    permissions {
        int id
        string name
        int scope_id
        string description
    }

    rbac_roles {
        int id
        string name
        uuid org_id
        int scope_id
        string description
        boolean editable
    }

    role_permission_bindings {
        int permission_id
        int rbac_role_id
    }

    role_inheritance {
        int inheriting_role_id
        int inherited_role_id
    }

    subject_role_bindings {
        int id
        int role_id
        uuid org_id
        uuid project_id
        int subject_id
        string binding_source
    }

    subjects {
        int id
        string name
        string type
    }

    rbac_roles ||--o{ org_role_to_proj_role_mappings : org_role
    rbac_roles ||--o{ org_role_to_proj_role_mappings : proj_role

    org_role_to_proj_role_mappings {
        int org_role_id
        int proj_role_id
    }
```

### Subject System (Users & Groups)

```mermaid
erDiagram
    subjects ||--o| rbac_users : is_type
    subjects ||--o| groups : is_type

    rbac_users ||--o{ user_group_bindings : ""
    groups ||--o{ user_group_bindings : ""

    subjects {
        int id
        string name
        string type
    }

    rbac_users {
        int id
        string email
        string name
    }

    groups {
        int id
        uuid org_id
        uuid creator_id
        string description
    }

    user_group_bindings {
        int user_id
        int group_id
    }
```

### Identity Provider Integration

```mermaid
erDiagram
    rbac_users ||--o{ oidc_sessions : ""
    rbac_users ||--o{ oidc_users : ""

    rbac_users {
        int id
        string email
        string name
    }

    oidc_sessions {
        uuid id
        int user_id
        bytea refresh_token_enc
        bytea id_token_enc
        timestamp expires_at
    }

    oidc_users {
        uuid id
        int user_id
        string oidc_user_id
    }

    okta_integrations {
        int id
        uuid org_id
        uuid creator_id
        string saml_issuer
        boolean jit_provisioning_enabled
    }

    okta_users {
        int id
        uuid integration_id
        uuid org_id
        uuid user_id
        string email
    }

    saml_jit_users {
        int id
        uuid integration_id
        uuid org_id
        uuid user_id
        string email
    }

    idp_group_mapping {
        int id
        uuid organization_id
        uuid default_role_id
        array role_mapping
        array group_mapping
    }
```

### Legacy Tables

```mermaid
erDiagram
    projects ||--o{ collaborators : ""
    projects ||--o{ project_members : ""
    users ||--o{ project_members : ""
    users ||--o{ roles : ""

    projects {
        uuid id
        uuid project_id
        string repo_name
        uuid org_id
        string provider
    }

    collaborators {
        uuid id
        uuid project_id
        string github_username
        string github_uid
        boolean admin
        boolean push
        boolean pull
    }

    users {
        uuid id
        uuid user_id
        string github_uid
        string provider
    }

    project_members {
        uuid id
        uuid project_id
        uuid user_id
    }

    roles {
        uuid id
        uuid user_id
        uuid org_id
        string name
    }
```

### Key-Value Stores & Audit

```mermaid
erDiagram
    user_permissions_key_value_store {
        string key
        text value
    }

    project_access_key_value_store {
        string key
        text value
    }

    global_permissions_audit_log {
        int id
        string key
        text old_value
        text new_value
        string query_operation
        boolean notified
    }
```

### Background Job Tables

```mermaid
erDiagram
    collaborator_refresh_requests {
        uuid id
        uuid org_id
        string state
        uuid requester_user_id
    }

    rbac_refresh_project_access_requests {
        uuid id
        string state
        uuid org_id
        int user_id
    }

    rbac_refresh_all_permissions_requests {
        int id
        string state
        int organizations_updated
        int retries
    }

    group_management_request {
        int id
        string state
        uuid user_id
        uuid group_id
        string action
    }
```

## Schema Notes

### RBAC Architecture
- **Scopes** categorize permissions (org-level, project-level)
- **Permissions** are individual access rights within scopes
- **Roles** bundle multiple permissions together
- **Role Inheritance** allows roles to inherit permissions from other roles
- **Org-to-Project Mappings** automatically map organization roles to project roles

### Subject System (Polymorphic Design)
- **Subjects** is a base table for both users and groups
- **rbac_users** inherits from subjects (1:1 relationship)
- **groups** inherits from subjects (1:1 relationship)
- **subject_role_bindings** assigns roles to any subject with source tracking

### Binding Sources
The `subject_role_bindings.binding_source` enum tracks where role assignments originate:
- `github` - From GitHub collaborator permissions
- `bitbucket` - From Bitbucket collaborator permissions
- `gitlab` - From GitLab collaborator permissions
- `manually_assigned` - Manually assigned by admin
- `okta` - From Okta/SCIM integration
- `inherited_from_org_role` - Inherited from organization role
- `saml_jit` - From SAML just-in-time provisioning

### Repository Access Mapping
- Maps legacy repository permissions (admin/push/pull) to RBAC roles
- One mapping per organization
- References three different roles for each access level

### Identity Providers
- **OIDC**: OpenID Connect sessions and user mappings
- **Okta**: SAML/SCIM integration with JIT provisioning support
- **SAML JIT**: Just-in-time user provisioning via SAML

### Audit System
- Database trigger on `user_permissions_key_value_store` automatically logs changes
- Tracks old/new values for permission changes
- Notified flag for tracking alert status
