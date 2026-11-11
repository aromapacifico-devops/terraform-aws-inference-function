# Changelog

## [1.0.0]

### Added

- Focus confirmation pattern. A platform event bus, a rule that sends each published flight record of one mission type to a work queue through a delivery role, a dead letter queue with redrive from the work queue only, a function with its log group and an event source mapping that reports failures per message.
- Flight object bucket, versioned and encrypted with the objects key, with public access blocked and TLS required, and a case table with point-in-time recovery under the data key.
- Alarms on failed invocations and on messages in the dead letter queue.
- Inputs `data_key_arn`, `objects_key_arn`, `role_arns`, `names`, `mission_type`, `object_prefix`, `restricted_prefix`, `bedrock_model_id`, `function_package`, `processing`, `alarm_actions` and `force_destroy_data`, with their validations.
- Outputs of the bus, rule, queues, function, bucket, table and alarms.
