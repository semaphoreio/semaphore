variable "project_name" {
  type    = string
  default = ""
}

variable "branch" {
  type    = string
  default = "main"
}

variable "public_ssh_key_path" {
  type        = string
  description = "A path to a public ssh key file"
}