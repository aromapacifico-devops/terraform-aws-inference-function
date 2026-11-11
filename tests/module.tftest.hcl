# Plan-time tests against a mocked provider. They need no AWS account.
mock_provider "aws" {
  alias = "project"

  override_resource {
    target          = aws_sqs_queue.dead_letter
    override_during = plan
    values = {
      arn = "arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus-dlq"
      id  = "https://sqs.us-east-1.amazonaws.com/111122223333/fnc-aroma-test-sqs-focus-dlq"
    }
  }

  override_resource {
    target          = aws_sqs_queue.work
    override_during = plan
    values          = { arn = "arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus" }
  }

  override_resource {
    target          = aws_s3_bucket.objects
    override_during = plan
    values = {
      arn = "arn:aws:s3:::fnc-aroma-test-s3-flights"
      id  = "fnc-aroma-test-s3-flights"
    }
  }
}

variables {
  client      = "fnc"
  project     = "aroma"
  environment = "test"

  data_key_arn    = "arn:aws:kms:us-east-1:111122223333:key/data"
  objects_key_arn = "arn:aws:kms:us-east-1:111122223333:key/objects"

  role_arns = {
    function = "arn:aws:iam::111122223333:role/fnc-aroma-test-role-focus"
    delivery = "arn:aws:iam::111122223333:role/fnc-aroma-test-role-focusdlv"
  }

  names = {
    event_bus         = "fnc-aroma-test-evb-platform"
    rule              = "fnc-aroma-test-evr-focus"
    work_queue        = "fnc-aroma-test-sqs-focus"
    dead_letter_queue = "fnc-aroma-test-sqs-focus-dlq"
    function          = "fnc-aroma-test-fn-focus"
    objects_bucket    = "fnc-aroma-test-s3-flights"
    cases_table       = "fnc-aroma-test-ddb-cases"
    errors_alarm      = "fnc-aroma-test-alarm-focus-errors"
    dead_letter_alarm = "fnc-aroma-test-alarm-focus-dlq"
  }

  mission_type      = "FOCUS_CONFIRMATION"
  object_prefix     = "focus/"
  restricted_prefix = "restricted/"
  bedrock_model_id  = "us.amazon.nova-2-lite-v1:0"
  function_package  = { path = "tests/fixtures/function.zip" }
}

run "accepts_valid_governance_values" {
  command = plan

  providers = {
    aws.project = aws.project
  }
}

run "rejects_an_unknown_environment" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "rejects_an_invalid_client_code" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    client = "FNC"
  }

  expect_failures = [var.client]
}

run "starts_from_published_flight_records_only" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = aws_cloudwatch_event_bus.platform.name == "fnc-aroma-test-evb-platform"
    error_message = "The module must create the platform bus with the name the root builds."
  }

  assert {
    condition = jsondecode(aws_cloudwatch_event_rule.flight_published.event_pattern) == {
      "detail-type" = ["flight.record.published"]
      detail        = { mission_type = ["FOCUS_CONFIRMATION"] }
    }
    error_message = "The rule must match only published flight records of its mission type."
  }

  assert {
    condition     = aws_cloudwatch_event_rule.flight_published.event_bus_name == "fnc-aroma-test-evb-platform"
    error_message = "The rule must listen on the platform bus."
  }

  assert {
    condition = (
      aws_cloudwatch_event_target.work_queue.arn == "arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus" &&
      aws_cloudwatch_event_target.work_queue.role_arn == "arn:aws:iam::111122223333:role/fnc-aroma-test-role-focusdlv" &&
      aws_cloudwatch_event_target.work_queue.event_bus_name == "fnc-aroma-test-evb-platform"
    )
    error_message = "The rule must put records on the work queue through the delivery role."
  }
}

run "moves_exhausted_messages_to_the_dead_letter_queue" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = jsondecode(aws_sqs_queue.work.redrive_policy) == {
      deadLetterTargetArn = "arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus-dlq"
      maxReceiveCount     = 4
    }
    error_message = "The work queue must redrive to its dead letter queue after four receives."
  }

  assert {
    condition     = aws_sqs_queue.work.visibility_timeout_seconds == 1800 && aws_sqs_queue.dead_letter.message_retention_seconds == 1209600
    error_message = "Defaults must be a 1800 s visibility timeout and 14 days in the dead letter queue."
  }

  assert {
    condition = jsondecode(aws_sqs_queue_redrive_allow_policy.dead_letter.redrive_allow_policy) == {
      redrivePermission = "byQueue"
      sourceQueueArns   = ["arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus"]
    }
    error_message = "Only the work queue may redrive into the dead letter queue."
  }

  assert {
    condition = alltrue([
      for queue in [aws_sqs_queue.work, aws_sqs_queue.dead_letter] : queue.kms_master_key_id == "arn:aws:kms:us-east-1:111122223333:key/data"
    ])
    error_message = "Both queues must use the data key."
  }
}

run "runs_the_function_on_demand_from_the_queue" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = (
      aws_lambda_function.this.role == "arn:aws:iam::111122223333:role/fnc-aroma-test-role-focus" &&
      aws_lambda_function.this.timeout == 300 &&
      aws_lambda_function.this.architectures == tolist(["arm64"])
    )
    error_message = "The function must run with the function role, a 300 s timeout and arm64."
  }

  assert {
    condition = aws_lambda_function.this.environment[0].variables == tomap({
      OBJECTS_BUCKET    = "fnc-aroma-test-s3-flights"
      OBJECT_PREFIX     = "focus/"
      RESTRICTED_PREFIX = "restricted/"
      CASES_TABLE       = "fnc-aroma-test-ddb-cases"
      EVENT_BUS         = "fnc-aroma-test-evb-platform"
      MODEL_ID          = "us.amazon.nova-2-lite-v1:0"
      ENVIRONMENT       = "test"
    })
    error_message = "The function must receive its bucket, prefixes, table, bus and model as configuration."
  }

  assert {
    condition = (
      aws_lambda_event_source_mapping.work_queue.event_source_arn == "arn:aws:sqs:us-east-1:111122223333:fnc-aroma-test-sqs-focus" &&
      aws_lambda_event_source_mapping.work_queue.batch_size == 1 &&
      aws_lambda_event_source_mapping.work_queue.function_response_types == toset(["ReportBatchItemFailures"]) &&
      aws_lambda_event_source_mapping.work_queue.scaling_config[0].maximum_concurrency == 2
    )
    error_message = "The mapping must read one flight per batch from the work queue, report failures per message and cap at two pollers."
  }

  assert {
    condition     = aws_cloudwatch_log_group.function.name == "/aws/lambda/fnc-aroma-test-fn-focus" && aws_cloudwatch_log_group.function.retention_in_days == 30
    error_message = "The function log group must keep 30 days under the name the security module scopes."
  }
}

run "keeps_objects_and_cases_protected" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition     = aws_s3_bucket_versioning.objects.versioning_configuration[0].status == "Enabled"
    error_message = "The bucket must keep every object version the flight record names."
  }

  assert {
    condition = alltrue([
      for rule in aws_s3_bucket_server_side_encryption_configuration.objects.rule :
      rule.bucket_key_enabled && one(rule.apply_server_side_encryption_by_default).kms_master_key_id == "arn:aws:kms:us-east-1:111122223333:key/objects"
    ])
    error_message = "The bucket must use the objects key with S3 Bucket Keys."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.objects.block_public_acls &&
      aws_s3_bucket_public_access_block.objects.block_public_policy &&
      aws_s3_bucket_public_access_block.objects.ignore_public_acls &&
      aws_s3_bucket_public_access_block.objects.restrict_public_buckets
    )
    error_message = "The bucket must block all public access."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.objects.policy).Statement[0].Condition == { Bool = { "aws:SecureTransport" = "false" } }
    error_message = "The bucket must deny requests without TLS."
  }

  assert {
    condition = (
      aws_dynamodb_table.cases.deletion_protection_enabled &&
      aws_dynamodb_table.cases.point_in_time_recovery[0].enabled &&
      aws_dynamodb_table.cases.server_side_encryption[0].kms_key_arn == "arn:aws:kms:us-east-1:111122223333:key/data"
    )
    error_message = "The case table must keep deletion protection, point-in-time recovery and the data key."
  }

  assert {
    condition     = !aws_s3_bucket.objects.force_destroy
    error_message = "A destroy must not remove flight objects by default."
  }
}

run "lets_a_demonstration_environment_come_down" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    force_destroy_data = true
  }

  assert {
    condition     = aws_s3_bucket.objects.force_destroy && !aws_dynamodb_table.cases.deletion_protection_enabled
    error_message = "force_destroy_data must let the bucket and the table go."
  }
}

run "raises_alarms_on_failures" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.errors.metric_name == "Errors" &&
      aws_cloudwatch_metric_alarm.errors.dimensions == tomap({ FunctionName = "fnc-aroma-test-fn-focus" }) &&
      aws_cloudwatch_metric_alarm.errors.threshold == 0
    )
    error_message = "One alarm must fire on any failed invocation of the function."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.dead_letter.metric_name == "ApproximateNumberOfMessagesVisible" &&
      aws_cloudwatch_metric_alarm.dead_letter.dimensions == tomap({ QueueName = "fnc-aroma-test-sqs-focus-dlq" }) &&
      aws_cloudwatch_metric_alarm.dead_letter.threshold == 0
    )
    error_message = "One alarm must fire on any message in the dead letter queue."
  }
}

run "rejects_a_visibility_timeout_shorter_than_six_function_timeouts" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    processing = { timeout_seconds = 300, visibility_timeout_seconds = 900 }
  }

  expect_failures = [var.processing]
}

run "rejects_one_poller" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    processing = { maximum_concurrency = 1 }
  }

  expect_failures = [var.processing]
}

run "rejects_the_default_bus" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    names = merge(var.names, { event_bus = "default" })
  }

  expect_failures = [var.names]
}

run "rejects_a_restricted_prefix_inside_the_object_prefix" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    restricted_prefix = "focus/restricted/"
  }

  expect_failures = [var.restricted_prefix]
}

run "rejects_one_role_for_function_and_rule" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    role_arns = {
      function = "arn:aws:iam::111122223333:role/fnc-aroma-test-role-focus"
      delivery = "arn:aws:iam::111122223333:role/fnc-aroma-test-role-focus"
    }
  }

  expect_failures = [var.role_arns]
}
