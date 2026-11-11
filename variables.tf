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

variable "data_key_arn" {
  description = "ARN of the data key from the security module. It encrypts the case table, both queues and the log group."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.data_key_arn))
    error_message = "data_key_arn must be the ARN of a KMS key."
  }
}

variable "objects_key_arn" {
  description = "ARN of the objects key from the security module. It encrypts the flight object bucket."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.objects_key_arn))
    error_message = "objects_key_arn must be the ARN of a KMS key."
  }
}

variable "role_arns" {
  description = "ARNs of the roles from the security module. function runs the function, delivery lets the rule put flight records on the work queue."
  type = object({
    function = string
    delivery = string
  })

  validation {
    condition     = alltrue([for arn in values(var.role_arns) : can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$", arn))])
    error_message = "Each value of role_arns must be the ARN of an IAM role."
  }

  validation {
    condition     = var.role_arns.function != var.role_arns.delivery
    error_message = "The function and the rule need different roles."
  }
}

variable "names" {
  description = "Final names of the resources, built by the root with the naming convention."
  type = object({
    event_bus         = string
    rule              = string
    work_queue        = string
    dead_letter_queue = string
    function          = string
    objects_bucket    = string
    cases_table       = string
    errors_alarm      = string
    dead_letter_alarm = string
  })

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,256}$", var.names.event_bus)) && var.names.event_bus != "default"
    error_message = "names.event_bus must be a custom bus name of letters, digits, dots, hyphens and underscores, other than default."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,64}$", var.names.rule))
    error_message = "names.rule may hold up to 64 letters, digits, dots, hyphens and underscores."
  }

  validation {
    condition     = alltrue([for name in [var.names.work_queue, var.names.dead_letter_queue] : can(regex("^[A-Za-z0-9_-]{1,80}$", name))])
    error_message = "Queue names may hold up to 80 letters, digits, hyphens and underscores, and no queue is FIFO."
  }

  validation {
    condition     = var.names.work_queue != var.names.dead_letter_queue
    error_message = "The work queue and the dead letter queue need different names."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,64}$", var.names.function))
    error_message = "names.function may hold up to 64 letters, digits, hyphens and underscores."
  }

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.names.objects_bucket))
    error_message = "names.objects_bucket must be a valid S3 bucket name."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]{3,255}$", var.names.cases_table))
    error_message = "names.cases_table must be a valid DynamoDB table name."
  }

  validation {
    condition     = alltrue([for name in [var.names.errors_alarm, var.names.dead_letter_alarm] : length(name) > 0 && length(name) <= 255])
    error_message = "Alarm names need 1 to 255 characters."
  }
}

variable "mission_type" {
  description = "Mission type of the published flight records this function processes, such as FOCUS_CONFIRMATION."
  type        = string

  validation {
    condition     = can(regex("^[A-Z][A-Z_]{1,63}$", var.mission_type))
    error_message = "mission_type must be an uppercase code with underscores, such as FOCUS_CONFIRMATION."
  }
}

variable "object_prefix" {
  description = "Bucket prefix whose objects the function reads, such as focus/. The security module scopes the role to the same prefix."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*/$", var.object_prefix))
    error_message = "object_prefix must be a relative path that ends with / and holds no wildcard, such as focus/."
  }
}

variable "restricted_prefix" {
  description = "Bucket prefix that receives objects with a person, such as restricted/."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*/$", var.restricted_prefix))
    error_message = "restricted_prefix must be a relative path that ends with / and holds no wildcard, such as restricted/."
  }

  validation {
    condition     = !startswith(var.restricted_prefix, var.object_prefix) && !startswith(var.object_prefix, var.restricted_prefix)
    error_message = "object_prefix and restricted_prefix must not contain each other, so a moved object never lands where it is read."
  }
}

variable "bedrock_model_id" {
  description = "Model or inference profile the function invokes, such as us.amazon.nova-2-lite-v1:0. The function receives it as configuration."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9.:_-]{1,128}$", var.bedrock_model_id))
    error_message = "bedrock_model_id must be a Bedrock model or inference profile identifier with no wildcard."
  }
}

variable "function_package" {
  description = "Deployment package of the function. The module deploys it and holds no function code."
  type = object({
    path    = string
    handler = optional(string, "main.handler")
    runtime = optional(string, "python3.13")
  })

  validation {
    condition     = endswith(var.function_package.path, ".zip")
    error_message = "function_package.path must point to a .zip file."
  }
}

variable "processing" {
  description = "Limits of the function and its queues. A message moves to the dead letter queue after max_receive_count receives. The visibility timeout must be at least six times the function timeout, as the Lambda guide for SQS recommends."
  type = object({
    timeout_seconds               = optional(number, 300)
    memory_mb                     = optional(number, 256)
    batch_size                    = optional(number, 1)
    maximum_concurrency           = optional(number, 2)
    max_receive_count             = optional(number, 4)
    visibility_timeout_seconds    = optional(number, 1800)
    dead_letter_retention_seconds = optional(number, 1209600)
  })
  default = {}

  validation {
    condition     = var.processing.timeout_seconds >= 1 && var.processing.timeout_seconds <= 900
    error_message = "processing.timeout_seconds must be between 1 and 900."
  }

  validation {
    condition     = var.processing.memory_mb >= 128 && var.processing.memory_mb <= 10240
    error_message = "processing.memory_mb must be between 128 and 10240."
  }

  validation {
    condition     = var.processing.batch_size >= 1 && var.processing.batch_size <= 10
    error_message = "processing.batch_size must be between 1 and 10, since the mapping waits for no batching window."
  }

  validation {
    condition     = var.processing.maximum_concurrency >= 2 && var.processing.maximum_concurrency <= 1000
    error_message = "processing.maximum_concurrency must be between 2 and 1000."
  }

  validation {
    condition     = var.processing.max_receive_count >= 1 && var.processing.max_receive_count <= 1000
    error_message = "processing.max_receive_count must be between 1 and 1000."
  }

  validation {
    condition     = var.processing.visibility_timeout_seconds >= 6 * var.processing.timeout_seconds && var.processing.visibility_timeout_seconds <= 43200
    error_message = "processing.visibility_timeout_seconds must be at least six times the function timeout and at most 43200."
  }

  validation {
    condition     = var.processing.dead_letter_retention_seconds >= 60 && var.processing.dead_letter_retention_seconds <= 1209600
    error_message = "processing.dead_letter_retention_seconds must be between 60 and 1209600."
  }
}

variable "alarm_actions" {
  description = "ARNs notified when an alarm of the function fires. Empty until the operational alarm routes exist."
  type        = list(string)
  default     = []
}

variable "force_destroy_data" {
  description = "Lets a destroy remove the flight objects and the case table. Keep it false where data must survive."
  type        = bool
  default     = false
}
