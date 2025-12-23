provider "keycloak" {
  client_id = "admin-cli"
  url       = var.keycloak_url
  username  = var.keycloak_admin_username
  password  = var.keycloak_admin_password
  realm     = "master"
}

// master realm configuration
data "keycloak_realm" "master_realm" {
  realm = "master"
}

resource "keycloak_realm_events" "master_realm_events" {
  realm_id = data.keycloak_realm.master_realm.id

  events_enabled    = true
  events_expiration = 108000

  admin_events_enabled         = true
  admin_events_details_enabled = true

  events_listeners = [
    "jboss-logging",
  ]
}

// REALM
resource "keycloak_realm" "semaphore_realm" {
  enabled = true
  realm   = var.semaphore_realm

  login_theme = var.semaphore_realm_login_theme

  access_token_lifespan        = var.semaphore_realm_access_token_lifespan
  offline_session_idle_timeout = var.semaphore_realm_offline_session_idle_timeout

  sso_session_idle_timeout = var.semaphore_realm_session_idle_timeout
  sso_session_max_lifespan = var.semaphore_realm_session_max_lifespan

  registration_email_as_username = true
  verify_email                   = false
  login_with_email_allowed       = true
  duplicate_emails_allowed       = false

  revoke_refresh_token = false
}

resource "keycloak_realm_events" "realm_events" {
  realm_id = keycloak_realm.semaphore_realm.id

  events_enabled    = true
  events_expiration = 108000 # One month

  admin_events_enabled         = true
  admin_events_details_enabled = true

  events_listeners = [
    "jboss-logging"
  ]
}

// CLIENT - semaphore user management
resource "keycloak_openid_client" "semaphore_user_management_client" {
  enabled       = true
  realm_id      = keycloak_realm.semaphore_realm.id
  name          = var.semaphore_user_management_client_name
  client_id     = var.semaphore_user_management_client_id
  client_secret = var.semaphore_user_management_client_secret

  access_type = "CONFIDENTIAL"

  service_accounts_enabled = true
}

resource "keycloak_openid_client" "account_console_client" {
  realm_id    = keycloak_realm.semaphore_realm.id
  client_id   = "account-console"
  enabled     = false
  access_type = "PUBLIC"
  import      = true
}

data "keycloak_openid_client" "realm_management" {
  realm_id  = keycloak_realm.semaphore_realm.id
  client_id = "realm-management"
}

data "keycloak_role" "manage_users" {
  realm_id  = keycloak_realm.semaphore_realm.id
  client_id = data.keycloak_openid_client.realm_management.id
  name      = "manage-users"
}

resource "keycloak_user_roles" "service_account_user_roles" {
  realm_id = keycloak_realm.semaphore_realm.id
  user_id  = keycloak_openid_client.semaphore_user_management_client.service_account_user_id

  role_ids = [
    data.keycloak_role.manage_users.id
  ]
}

// CLIENT - semaphore
resource "keycloak_openid_client" "semaphore" {
  enabled       = true
  realm_id      = keycloak_realm.semaphore_realm.id
  name          = var.semaphore_client_name
  client_id     = var.semaphore_client_id
  client_secret = var.semaphore_client_secret

  access_type           = "CONFIDENTIAL"
  standard_flow_enabled = true

  root_url                            = var.semaphore_client_root_url
  base_url                            = var.semaphore_client_base_url
  admin_url                           = var.semaphore_client_admin_url
  valid_redirect_uris                 = var.semaphore_client_valid_redirect_uris
  valid_post_logout_redirect_uris     = var.semaphore_client_valid_post_logout_redirect_uris
  web_origins                         = var.semaphore_client_web_origins
  frontchannel_logout_enabled         = true
  backchannel_logout_session_required = true
}

// Realm required actions

resource "keycloak_required_action" "configure-totp" {
  realm_id = keycloak_realm.semaphore_realm.realm
  alias    = "CONFIGURE_TOTP"
  enabled  = false
  name     = "Configure OTP"
}

resource "keycloak_required_action" "update-password" {
  realm_id = keycloak_realm.semaphore_realm.realm
  alias    = "UPDATE_PASSWORD"
  enabled  = var.semaphore_realm_update_password_action
  name     = "Update Password"
}

resource "keycloak_required_action" "webauthn-register" {
  realm_id = keycloak_realm.semaphore_realm.realm
  alias    = "webauthn-register"
  enabled  = false
  name     = "Webauthn Register"
}

// IDENTITY PROVIDER - Github
resource "keycloak_oidc_identity_provider" "github_provider" {
  realm             = keycloak_realm.semaphore_realm.id
  display_name      = "Github"
  provider_id       = "github"
  alias             = "github"
  authorization_url = var.github_provider_authorization_url
  client_id         = var.github_provider_client_id
  client_secret     = var.github_provider_client_secret
  token_url         = ""

  trust_email                   = true
  store_token                   = false
  default_scopes                = "user:email"
  first_broker_login_flow_alias = ""

  sync_mode = "IMPORT"
}

// IDENTITY PROVIDER - Bitbucket
resource "keycloak_oidc_identity_provider" "bitbucket_provider" {
  realm             = keycloak_realm.semaphore_realm.id
  display_name      = "Bitbucket"
  provider_id       = "bitbucket"
  alias             = "bitbucket"
  authorization_url = var.bitbucket_provider_authorization_url
  client_id         = var.bitbucket_provider_client_id
  client_secret     = var.bitbucket_provider_client_secret
  token_url         = ""

  trust_email                   = true
  store_token                   = false
  default_scopes                = ""
  first_broker_login_flow_alias = ""

  sync_mode = "IMPORT"
}

// IDENTITY PROVIDER - Gitlab
resource "keycloak_oidc_identity_provider" "gitlab_provider" {
  realm             = keycloak_realm.semaphore_realm.id
  display_name      = "Gitlab"
  provider_id       = "gitlab"
  alias             = "gitlab"
  authorization_url = var.gitlab_provider_authorization_url
  client_id         = var.gitlab_provider_client_id
  client_secret     = var.gitlab_provider_client_secret
  token_url         = ""

  trust_email                   = true
  store_token                   = false
  default_scopes                = "api read_user read_repository write_repository openid"
  first_broker_login_flow_alias = ""

  sync_mode = "IMPORT"
}

// MCP OAuth 2.1 Client Scope
// This scope is used for Dynamic Client Registration (DCR) and MCP server access
resource "keycloak_openid_client_scope" "mcp" {
  realm_id               = keycloak_realm.semaphore_realm.id
  name                   = "mcp"
  description            = "MCP server access scope for OAuth 2.1"
  include_in_token_scope = true
}

// IMPORTANT: Client Registration Policies Configuration
// Keycloak Terraform provider doesn't fully support Client Registration Policies.
// You must manually configure in Keycloak Admin UI:
//
// Navigate to: Clients → Client Registration → Anonymous Access Policies
//
// Required Configuration:
// 1. "Allowed Client Scopes" policy:
//    - Add "mcp" to the list of allowed scopes
//    - This allows DCR clients to request the mcp scope
//
// 2. "Default Client Scopes" policy:
//    - Create or edit this policy
//    - Add "mcp" to the list of default scopes
//    - This ensures all dynamically registered clients get the mcp scope by default
//    - CRITICAL: This makes Claude Code and other MCP clients automatically use scope=mcp
//      during authorization, even if they don't explicitly request it
//
// 3. "Trusted Hosts" policy:
//    - EITHER: Delete this policy entirely (recommended for internal/dev environments)
//    - OR: Add trusted host patterns that include:
//      * Pod network CIDR (e.g., "10.*" for Kubernetes pod IPs)
//      * "127.0.0.1", "localhost" for local testing
//    - Note: Auth service proxies DCR requests, so Keycloak sees the auth pod IP,
//      not the original client IP
//
// 4. Verify "Max Clients" and other policies don't block DCR as needed

// Map semaphore_user_id user attribute to JWT claim
resource "keycloak_openid_user_attribute_protocol_mapper" "semaphore_user_id" {
  realm_id        = keycloak_realm.semaphore_realm.id
  client_scope_id = keycloak_openid_client_scope.mcp.id
  name            = "semaphore-user-id-mapper"

  user_attribute      = "semaphore_user_id"
  claim_name          = "semaphore_user_id"
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
  claim_value_type    = "String"
}

// Audience mapper for MCP resource server (required for JWT aud validation)
resource "keycloak_openid_audience_protocol_mapper" "mcp_audience" {
  realm_id                 = keycloak_realm.semaphore_realm.id
  client_scope_id          = keycloak_openid_client_scope.mcp.id
  name                     = "mcp-audience"
  included_custom_audience = "https://mcp.${var.base_domain}"
}

// MCP grant ID session note mapper - adds mcp_grant_id from user session to JWT
// This is set during OAuth consent flow and persists for the session
resource "keycloak_openid_user_session_note_protocol_mapper" "mcp_grant_id" {
  realm_id        = keycloak_realm.semaphore_realm.id
  client_scope_id = keycloak_openid_client_scope.mcp.id
  name            = "mcp-grant-id-mapper"

  claim_name          = "mcp_grant_id"
  session_note        = "mcp_grant_id"
  add_to_id_token     = true
  add_to_access_token = true
  claim_value_type    = "String"
}

// MCP tool scopes array mapper - adds list of granted tool scopes to JWT
// This allows quick scope validation without database lookup
resource "keycloak_openid_user_session_note_protocol_mapper" "mcp_tool_scopes" {
  realm_id        = keycloak_realm.semaphore_realm.id
  client_scope_id = keycloak_openid_client_scope.mcp.id
  name            = "mcp-tool-scopes-mapper"

  claim_name          = "mcp_tool_scopes"
  session_note        = "mcp_tool_scopes"
  add_to_id_token     = false
  add_to_access_token = true
  claim_value_type    = "JSON"
}

// Realm User Profile
resource "keycloak_realm_user_profile" "userprofile" {
  realm_id = keycloak_realm.semaphore_realm.id

  attribute {
    name         = "username"
    display_name = "$${username}"

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "length"
      config = {
        min = 3
        max = 255
      }
    }

    validator {
      name = "email"
    }
  }

  attribute {
    name         = "email"
    display_name = "$${email}"

    required_for_roles = ["user"]

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "email"
    }

    validator {
      name = "length"
      config = {
        max = 255
      }
    }
  }

  attribute {
    name         = "firstName"
    display_name = "$${firstName}"

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "length"
      config = {
        max = 255
      }
    }
  }

  attribute {
    name         = "lastName"
    display_name = "$${lastName}"

    permissions {
      view = ["admin", "user"]
      edit = ["admin", "user"]
    }

    validator {
      name = "length"
      config = {
        max = 255
      }
    }
  }

  // Semaphore User ID - synced from Guard service, used in MCP JWT tokens
  attribute {
    name         = "semaphore_user_id"
    display_name = "Semaphore User ID"

    permissions {
      view = ["admin"]
      edit = ["admin"]
    }

    validator {
      name = "length"
      config = {
        min = 36
        max = 36
      }
    }
  }
}
