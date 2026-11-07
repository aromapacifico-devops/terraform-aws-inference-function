# Input variables of the sample.
variable "client" {
  description = "Client code."
  type        = string
}

variable "project" {
  description = "Project code."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "region" {
  description = "AWS Region of the sample."
  type        = string
}

variable "deploy_role_arn" {
  description = "Role to assume. Leave empty to use the local credentials."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags applied to every resource through the provider."
  type        = map(string)
}
