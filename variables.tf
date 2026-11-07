# Input variables of the module.
variable "client" {
  description = "Client code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.client))
    error_message = "client must be 1 to 10 lowercase alphanumeric characters."
  }
}

variable "project" {
  description = "Project code, used in names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{1,15}$", var.project))
    error_message = "project must be 1 to 15 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test or prod."
  }
}

variable "additional_tags" {
  description = "Tags added to the resources of this module, on top of the provider default tags."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for key in keys(var.additional_tags) : length(trimspace(key)) > 0])
    error_message = "additional_tags keys cannot be empty."
  }
}
