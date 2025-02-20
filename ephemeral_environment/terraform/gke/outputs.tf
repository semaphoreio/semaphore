output "cluster_name" {
  value = google_container_cluster.cluster.name
}

output "external_ip_address" {
  value = google_compute_global_address.external_address.address
}

output "external_ip_name" {
  value = google_compute_global_address.external_address.name
}

output "ssl_cert_name" {
  value = google_compute_ssl_certificate.ssl_cert.name
}
