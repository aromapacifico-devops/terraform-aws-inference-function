# Local values and transformations of the module.
locals {
  event_pattern = {
    "detail-type" = ["flight.record.published"]
    detail        = { mission_type = [var.mission_type] }
  }

  log_group = "/aws/lambda/${var.names.function}"

  # Configuration the function reads. Prompts and model identifiers are configuration, never code.
  function_environment = {
    OBJECTS_BUCKET    = var.names.objects_bucket
    OBJECT_PREFIX     = var.object_prefix
    RESTRICTED_PREFIX = var.restricted_prefix
    CASES_TABLE       = var.names.cases_table
    EVENT_BUS         = var.names.event_bus
    MODEL_ID          = var.bedrock_model_id
    ENVIRONMENT       = var.environment
  }
}
