terraform {
  backend "kubernetes" {
    secret_suffix     = "keycloak-configuration"
    in_cluster_config = true
  }

  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.1.0"
    }
  }
}
