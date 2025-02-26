output "ssl_cert_name" {
  description = "ARN of the SSL certificate"
  value       = aws_acm_certificate.cert.arn
}
