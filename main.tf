# Resources of the module. Every resource sets provider = aws.project.

# Bus that carries the platform events, such as flight.record.published and inference.completed.
resource "aws_cloudwatch_event_bus" "platform" {
  provider = aws.project

  name        = var.names.event_bus
  description = "Platform events of ${var.client} ${var.project} in ${var.environment}"

  tags = merge(var.additional_tags, { Name = var.names.event_bus })
}

# A published flight record of this mission type goes to the work queue. Raw object uploads start nothing.
resource "aws_cloudwatch_event_rule" "flight_published" {
  provider = aws.project

  name           = var.names.rule
  description    = "Published ${var.mission_type} flight records to the work queue of ${var.names.function}"
  event_bus_name = aws_cloudwatch_event_bus.platform.name
  event_pattern  = jsonencode(local.event_pattern)

  tags = merge(var.additional_tags, { Name = var.names.rule })
}

resource "aws_cloudwatch_event_target" "work_queue" {
  provider = aws.project

  rule           = aws_cloudwatch_event_rule.flight_published.name
  event_bus_name = aws_cloudwatch_event_bus.platform.name
  target_id      = "work-queue"
  arn            = aws_sqs_queue.work.arn
  role_arn       = var.role_arns.delivery
}

# Queues. SQS moves a message to the dead letter queue after max_receive_count receives.
resource "aws_sqs_queue" "dead_letter" {
  provider = aws.project

  name                              = var.names.dead_letter_queue
  message_retention_seconds         = var.processing.dead_letter_retention_seconds
  kms_master_key_id                 = var.data_key_arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.additional_tags, { Name = var.names.dead_letter_queue })
}

resource "aws_sqs_queue" "work" {
  provider = aws.project

  name                              = var.names.work_queue
  visibility_timeout_seconds        = var.processing.visibility_timeout_seconds
  kms_master_key_id                 = var.data_key_arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter.arn
    maxReceiveCount     = var.processing.max_receive_count
  })

  tags = merge(var.additional_tags, { Name = var.names.work_queue })
}

# Only the work queue may redrive into the dead letter queue.
resource "aws_sqs_queue_redrive_allow_policy" "dead_letter" {
  provider = aws.project

  queue_url = aws_sqs_queue.dead_letter.id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.work.arn]
  })
}

# Flight objects. Versioning keeps every object version the flight record names.
resource "aws_s3_bucket" "objects" {
  #checkov:skip=CKV2_AWS_62:The function starts from the published flight record, see docs/iac-exceptions.md
  #checkov:skip=CKV_AWS_18:Object deliveries are recorded as S3 data events in the audit trail, see docs/iac-exceptions.md
  #checkov:skip=CKV_AWS_144:The pilot runs in one Region, see docs/iac-exceptions.md
  provider = aws.project

  bucket        = var.names.objects_bucket
  force_destroy = var.force_destroy_data

  tags = merge(var.additional_tags, { Name = var.names.objects_bucket })
}

resource "aws_s3_bucket_public_access_block" "objects" {
  provider = aws.project

  bucket                  = aws_s3_bucket.objects.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "objects" {
  provider = aws.project

  bucket = aws_s3_bucket.objects.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "objects" {
  provider = aws.project

  bucket = aws_s3_bucket.objects.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.objects_key_arn
    }
  }
}

resource "aws_s3_bucket_versioning" "objects" {
  provider = aws.project

  bucket = aws_s3_bucket.objects.id

  versioning_configuration {
    status = "Enabled"
  }
}

# A flight with an unfinished upload is never published, so its parts only cost storage.
resource "aws_s3_bucket_lifecycle_configuration" "objects" {
  provider = aws.project

  bucket = aws_s3_bucket.objects.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.objects]
}

resource "aws_s3_bucket_policy" "objects" {
  provider = aws.project

  bucket = aws_s3_bucket.objects.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.objects.arn, "${aws_s3_bucket.objects.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.objects]
}

# Cases, their results and the idempotency keys. Deletion protection follows force_destroy_data.
resource "aws_dynamodb_table" "cases" {
  provider = aws.project

  name                        = var.names.cases_table
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "pk"
  range_key                   = "sk"
  deletion_protection_enabled = !var.force_destroy_data

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.data_key_arn
  }

  tags = merge(var.additional_tags, { Name = var.names.cases_table })
}

resource "aws_cloudwatch_log_group" "function" {
  #checkov:skip=CKV_AWS_338:Operational logs keep 30 days, see docs/iac-exceptions.md
  provider = aws.project

  name              = local.log_group
  retention_in_days = 30
  kms_key_id        = var.data_key_arn

  tags = merge(var.additional_tags, { Name = local.log_group })
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_115:The account allows 10 concurrent executions and the mapping caps pollers, see docs/iac-exceptions.md
  #checkov:skip=CKV_AWS_116:Failed records reach the dead letter queue of the work queue, see docs/iac-exceptions.md
  #checkov:skip=CKV_AWS_117:The function calls regional AWS APIs only, see docs/iac-exceptions.md
  #checkov:skip=CKV_AWS_173:Environment variables hold names only, see docs/iac-exceptions.md
  #checkov:skip=CKV_AWS_272:No signing profile exists yet, see docs/iac-exceptions.md
  #checkov:skip=CKV_AWS_50:Traces are outside the current observability design, see docs/iac-exceptions.md
  provider = aws.project

  function_name    = var.names.function
  role             = var.role_arns.function
  filename         = var.function_package.path
  source_code_hash = filebase64sha256(var.function_package.path)
  handler          = var.function_package.handler
  runtime          = var.function_package.runtime
  architectures    = ["arm64"]
  memory_size      = var.processing.memory_mb
  timeout          = var.processing.timeout_seconds

  environment {
    variables = local.function_environment
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.function.name
  }

  tags = merge(var.additional_tags, { Name = var.names.function })
}

# Lambda polls the queue only while messages wait, and reports failures per message.
resource "aws_lambda_event_source_mapping" "work_queue" {
  provider = aws.project

  event_source_arn                   = aws_sqs_queue.work.arn
  function_name                      = aws_lambda_function.this.arn
  batch_size                         = var.processing.batch_size
  maximum_batching_window_in_seconds = 0
  function_response_types            = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = var.processing.maximum_concurrency
  }

  tags = merge(var.additional_tags, { Name = "${var.names.function}-queue" })
}

# Any failed invocation, and any message that reached the dead letter queue, raise an alarm.
resource "aws_cloudwatch_metric_alarm" "errors" {
  provider = aws.project

  alarm_name          = var.names.errors_alarm
  alarm_description   = "Failed invocations of ${var.names.function}"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.this.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  tags = merge(var.additional_tags, { Name = var.names.errors_alarm })
}

resource "aws_cloudwatch_metric_alarm" "dead_letter" {
  provider = aws.project

  alarm_name          = var.names.dead_letter_alarm
  alarm_description   = "Flight records that ${var.names.function} could not process"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dead_letter.name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_actions
  ok_actions          = var.alarm_actions

  tags = merge(var.additional_tags, { Name = var.names.dead_letter_alarm })
}
