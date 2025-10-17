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

The center of the RBAC system is the subject role bindings table, which assigns a role to a given subject (either a user or a group), and that role has a list of permissions attached to it.

There are two resources to which roles can be assigned: you can have a role within the organization, or you can have a role within the project. If you want to assign a role within the organization, that role has to be of the "organization scope", and if you want to assign a role within the project, then the role you are assigning must be of the "project scope".

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

### Additional Complexity

Role Inheritance

One role can inherit another role and all of its permissions. Every time we want to calculate the permissions you have, we have to check the roles you are assigned, but also all the roles they inherit. This is a redundant feature. We're not really using in our production setup (except some Insider roles). Even though this is tested and works, we've never really found a use for it. When you're trying to create a new role within the custom roles UI, there is no way for you to set up role inheritance.

Organization Role to Project Role Mappings

Another table is organization role to project role mappings, which also makes this a bit more complex. This is something we are using regularly. You can say that some organizational role, like "Owner", carries automatic "Admin" access to all of the projects within the organization. In this case, organization role "Owner" maps to project role "Admin", and this also has to be taken into consideration when we are checking if user has access to a project: Even though they might not have a role directly within the project, they maybe have an organization role which maps to project role.

Groups

The subject in subject role bindings can be a user, but it can also be a group. When we are actually trying to see which permissions a user has, we have to track all of the roles assigned directly. We also have to check if the user is part of a group, and then if they are, we also need to check all of the roles that the group has.
We have tested groups thoroughly, but I'm not sure if any customers are using them.

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
```

User Permission Key Value Store

All of this complexity makes actually figuring out which permissions a user has within an organization (or project) a bit more complex. It's not as simple as just tracking the subject role bindings table. It takes quite a few joins, and some recursive joins. Query which calculates all of the permisions for a given user/organization/project is written in the `Rbac.ComputePermissions` module of rhis service. Depending on the size of the organization, number of user and projects they have, it can take from >1s, to 6,7s to calculate these permission.

That's why we had a need for `user_permissions_key_value_store` and `project_access_key_value_store`. Instead of calculating all of the permissions for every "GET" query, there is one table which stores all of the permissions user has within the org and/or project, and another with list of projects user has access to within the organization.

These key value stores are recalculated anytime somebody is assigned a new role, anytime somebody's role is being removed, when you are joining a group, when you are being removed from a group, or when the role definition changes (which can happen with custom roles).

Performance Issues

As mentioned above, recalculation permissions usually takes around a second, but for some organizations that have a lot of projects, it can take five or six seconds. In some extreme cases, it can take around 10+ seconds, and this is where a problem occurs because we are hitting gRPC request timeout. You get bad UX experience when you want to change a role and you get a spinner for, let's say, 10 seconds, and it just times out. One major improvement we can do is to make role assignment and role retraction asynchronous, like many other operations in RBAC already are.

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

### Legacy Tables

These tables are leftover from the old auth system. We still use collaborators table when we want to sych GitHub repo access with the Semaphore project roles.

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