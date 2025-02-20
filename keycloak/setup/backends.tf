terraform {
  backend "kubernetes" {
    secret_suffix     = "keycloak-configuration"
    in_cluster_config = true
  }

  required_providers {
    keycloak = {
      source  = "mrparkers/keycloak"
      version = "4.4.0"
    }
  }
}
