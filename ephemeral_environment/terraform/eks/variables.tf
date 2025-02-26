variable "cluster_name" {
  type    = string
  default = "semaphore"
}

variable "aws_region" {
  type = string
}

variable "domain" {
  type = string
}

variable "route53_zone_id" {
  type = string
}