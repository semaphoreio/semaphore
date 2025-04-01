output "ssl_cert_name" {
  description = "ARN of the SSL certificate"
  value       = aws_acm_certificate.cert.arn
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.cluster.name
}
  