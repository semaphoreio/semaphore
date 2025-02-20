resource "google_container_cluster" "cluster" {
  name                     = substr("test-${var.branch}", 0, min(40, length("test-${var.branch}")))
  deletion_protection      = false
  project                  = var.project_name
  datapath_provider        = "LEGACY_DATAPATH"
  networking_mode          = "VPC_NATIVE"
  location                 = "us-east4"
  remove_default_node_pool = true
  initial_node_count       = 1

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "global-access-to-cluster"
    }
  }

  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "WORKLOADS",
    ]
  }

  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
    ]
    managed_prometheus {
      enabled = true
    }
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  service_external_ips_config {
    enabled = false
  }

  depends_on = [google_compute_ssl_certificate.ssl_cert, google_compute_global_address.external_address]
}

resource "google_container_node_pool" "node_pool" {
  name           = substr("test-pool-${var.branch}", 0, min(40, length("test-pool-${var.branch}")))
  node_count     = 1
  cluster        = google_container_cluster.cluster.name
  project        = var.project_name
  node_locations = ["us-east4-b"]

  node_config {
    service_account = ""
    machine_type    = "e2-custom-8-16384"
  }

  network_config {
    create_pod_range     = false
    enable_private_nodes = true
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
    strategy        = "SURGE"
  }

  queued_provisioning {
    enabled = false
  }

  depends_on = [google_container_cluster.cluster]
}

resource "google_compute_global_address" "external_address" {
  name         = substr("global-static-ip-address-${var.branch}", 0, min(40, length("global-static-ip-address-${var.branch}")))
  address_type = "EXTERNAL"
  description  = "Global address used by GCP LB"
}

resource "google_compute_ssl_certificate" "ssl_cert" {
  name        = substr("cert-${var.branch}", 0, min(40, length("cert-${var.branch}")))
  private_key = file("${var.path_to_private_key}")
  certificate = file("${var.path_to_fullchain_cer}")
}