# Transformations of the sample. The final resource names and the payload of the module are built here.
locals {
  name_prefix = "${var.client}-${var.project}-${var.environment}"

  role_names = {
    function = "${local.name_prefix}-role-focus"
    delivery = "${local.name_prefix}-role-focusdlv"
  }

  names = {
    event_bus         = "${local.name_prefix}-evb-platform"
    rule              = "${local.name_prefix}-evr-focus"
    work_queue        = "${local.name_prefix}-sqs-focus"
    dead_letter_queue = "${local.name_prefix}-sqs-focus-dlq"
    function          = "${local.name_prefix}-fn-focus"
    objects_bucket    = "${local.name_prefix}-s3-flights"
    cases_table       = "${local.name_prefix}-ddb-cases"
    errors_alarm      = "${local.name_prefix}-alarm-focus-errors"
    dead_letter_alarm = "${local.name_prefix}-alarm-focus-dlq"
  }
}
