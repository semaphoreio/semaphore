variable "keycloak_admin_username" {
  description = "Keycloak admin username"
  type        = string
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
}

variable "keycloak_url" {
  description = "Keycloak URL"
  type        = string
}

variable "semaphore_realm" {
  description = "Keycloak realm"
  type        = string
}

variable "semaphore_realm_session_idle_timeout" {
  description = "Semaphore realm session idle timeout"
  type        = string
  default     = "72h"
}

variable "semaphore_realm_session_max_lifespan" {
  description = "Semaphore realm session max lifespan"
  type        = string
  default     = "720h"
}

variable "semaphore_realm_access_token_lifespan" {
  description = "Semaphore realm access token lifespan"
  type        = string
  default     = "1h"
}

variable "semaphore_realm_offline_session_idle_timeout" {
  description = "Semaphore realm offline session idle timeout"
  type        = string
  default     = "720h"
}

variable "semaphore_realm_update_password_action" {
  description = "If enabled, newly created accounts will be required to update their password on first login"
  type        = bool
  default     = false
}

variable "semaphore_realm_login_theme" {
  description = "Theme for the login page"
  type        = string
  default     = "keycloak"
}

variable "semaphore_user_management_client_id" {
  description = "Semaphore user management client id"
  type        = string
}
variable "semaphore_user_management_client_name" {
  description = "Semaphore user management client name"
  type        = string
}

variable "semaphore_user_management_client_secret" {
  description = "Semaphore user management client secret"
  type        = string
  sensitive   = true
}

variable "semaphore_client_id" {
  description = "Semaphore client id"
  type        = string
}
variable "semaphore_client_name" {
  description = "Semaphore client name"
  type        = string
}

variable "semaphore_client_secret" {
  description = "Semaphore client secret"
  type        = string
  sensitive   = true
}

variable "semaphore_client_root_url" {
  description = "Semaphore client root url"
  type        = string
}

variable "semaphore_client_base_url" {
  description = "Semaphore client base url"
  type        = string
}

variable "semaphore_client_admin_url" {
  description = "Semaphore client admin url"
  type        = string
}

variable "semaphore_client_valid_redirect_uris" {
  description = "Semaphore client valid redirect uris"
  type        = list(any)
}

variable "semaphore_client_valid_post_logout_redirect_uris" {
  description = "Semaphore valid post logout redirect uris"
  type        = list(any)
}

variable "semaphore_client_web_origins" {
  description = "Semaphore client web origins"
  type        = list(any)
}

variable "github_provider_client_id" {
  description = "Github provider client id"
  type        = string
}

variable "github_provider_client_secret" {
  description = "Github provider client secret"
  type        = string
  sensitive   = true
}

variable "github_provider_authorization_url" {
  description = "Github provider authorization url"
  type        = string
}

variable "bitbucket_provider_client_id" {
  description = "Bitbucket provider client id"
  type        = string
}

variable "bitbucket_provider_client_secret" {
  description = "Bitbucket provider client secret"
  type        = string
  sensitive   = true
}

variable "bitbucket_provider_authorization_url" {
  description = "Bitbucket provider authorization url"
  type        = string
}

variable "gitlab_provider_client_id" {
  description = "Gitlab provider client id"
  type        = string
}

variable "gitlab_provider_client_secret" {
  description = "Gitlab provider client secret"
  type        = string
  sensitive   = true
}

variable "gitlab_provider_authorization_url" {
  description = "Gitlab provider authorization url"
  type        = string
}

variable "base_domain" {
  description = "Base domain for the MCP server (e.g., semaphoreci.com)"
  type        = string
}
