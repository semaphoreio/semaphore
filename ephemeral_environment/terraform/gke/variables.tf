variable "project_name" {
  type    = string
  default = ""
}

variable "branch" {
  type    = string
  default = "main"
}

variable "path_to_private_key" {
  type        = string
  description = "A path to a ssl certificate file with a private.key"
}

variable "path_to_fullchain_cer" {
  type        = string
  description = "A path to a ssl certificate file with a fullchain.cer"
}