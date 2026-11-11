# Outputs of the module. Each one exposes a single attribute and has a description.
output "event_bus_arn" {
  description = "ARN of the platform event bus."
  value       = aws_cloudwatch_event_bus.platform.arn
}

output "event_bus_name" {
  description = "Name of the platform event bus, where the mission link publishes flight records."
  value       = aws_cloudwatch_event_bus.platform.name
}

output "rule_arn" {
  description = "ARN of the rule that sends published flight records to the work queue."
  value       = aws_cloudwatch_event_rule.flight_published.arn
}

output "work_queue_arn" {
  description = "ARN of the work queue."
  value       = aws_sqs_queue.work.arn
}

output "dead_letter_queue_arn" {
  description = "ARN of the dead letter queue."
  value       = aws_sqs_queue.dead_letter.arn
}

output "function_arn" {
  description = "ARN of the function."
  value       = aws_lambda_function.this.arn
}

output "object_bucket_arn" {
  description = "ARN of the flight object bucket."
  value       = aws_s3_bucket.objects.arn
}

output "case_table_arn" {
  description = "ARN of the case table."
  value       = aws_dynamodb_table.cases.arn
}

output "alarm_arns" {
  description = "ARNs of the alarms, keyed errors and dead_letter."
  value = {
    errors      = aws_cloudwatch_metric_alarm.errors.arn
    dead_letter = aws_cloudwatch_metric_alarm.dead_letter.arn
  }
}
