resource "google_compute_instance" "instance" {
  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false
  machine_type        = "e2-standard-8"
  name                = "test-${var.branch}"
  tags                = ["http-server", "https-server"]
  zone                = "us-east4-c"

  metadata = {
    ssh-keys = "semaphore:${file(var.public_ssh_key_path)}"
  }

  boot_disk {
    auto_delete = true
    device_name = "test-${var.branch}"

    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2404-noble-amd64-v20241219"
      size  = 32
      type  = "pd-standard"
    }

    mode = "READ_WRITE"
  }

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/${var.project_name}/regions/us-east4/subnetworks/default"
  }
}
