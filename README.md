# terraform-aws-inference-function

Pattern of one event-driven inference function for the Aroma Pacifico platform, applied to focus confirmation. When the drone mission link has verified every object of a flight, it publishes the flight record on the platform bus. A rule puts that record on the work queue of the function, the function reads the exact object versions the record names, analyzes them with managed services and writes the result in the case table. The other functions of the design repeat this pattern with their own mission type, prefix, queue and role. It implements box C08 of the implementation scope, trigger, function and inference.

## Contents

- [Terms](#terms)
- [The pieces of the pattern](#the-pieces-of-the-pattern)
- [What it creates](#what-it-creates)
- [What it leaves to other places](#what-it-leaves-to-other-places)
- [Usage](#usage)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Design choices](#design-choices)
- [What happens when it fails](#what-happens-when-it-fails)
- [Cost](#cost)
- [Pending confirmations](#pending-confirmations)
- [Develop and test](#develop-and-test)
- [Versions](#versions)
- [Related repositories](#related-repositories)

## Terms

| Term | Meaning here |
|---|---|
| Flight record | Case entry the mission link publishes once the signed manifest, every mandatory object, its SHA-256 and its S3 version are verified |
| Platform bus | Custom EventBridge bus for the events of the platform, such as `flight.record.published` and `inference.completed` |
| Work queue | Standard SQS queue that holds the published flight records the function still has to process |
| Dead letter queue | Queue that receives a message the function failed to process after the allowed receives |
| Event source mapping | Lambda poller that reads the work queue only while messages wait |

## The pieces of the pattern

| Piece | How it is built here |
|---|---|
| Trigger | A rule on the platform bus that matches `flight.record.published` with one mission type and puts the record on the work queue |
| Read permission | The function reads exact object versions under one bucket prefix |
| Write permission | The function puts items in the case table and announces `inference.completed` on the platform bus |
| Inference permission | The function detects labels with Rekognition and invokes one Bedrock model |
| Failure queue | The work queue moves a message that keeps failing to its own dead letter queue |

Rekognition filters people before any analysis, and Bedrock performs the analysis. Both are managed services, so this module calls them and creates neither.

## What it creates

| Resource | Purpose |
|---|---|
| EventBridge bus | Platform bus where the mission link publishes flight records |
| EventBridge rule and target | Sends each published record of the mission type to the work queue, through the delivery role |
| Work queue | Holds records until the function processes them, encrypted with the data key |
| Dead letter queue | Keeps records the function could not process for 14 days, and accepts messages only from the work queue |
| S3 bucket | Flight objects, versioned and encrypted with the objects key, with public access blocked and TLS required |
| Case table | Cases, results and idempotency keys, encrypted with the data key, with point-in-time recovery |
| Lambda function | Runs the deployment package on arm64 |
| Log group | Logs of the function for 30 days, encrypted with the data key |
| Event source mapping | Reads one record per batch from the work queue and reports failures per message |
| CloudWatch alarms | One on failed invocations and one on messages in the dead letter queue |

The function code stays out of this module. It receives a deployment package and passes the bucket, prefixes, table, bus and model to the function as environment variables.

## What it leaves to other places

| Need | Where it lives | Why |
|---|---|---|
| Function role and delivery role | Security module | Every identity of the platform lives there, with its permissions |
| Data and objects keys | Security module | The keys are shared by every workload of an environment |
| Function code, prompt and result envelope | Platform application | The project builds no application logic |
| Publishing flight records | Drone mission link | Only the completion check knows that a flight is whole |
| Alarm notifications | Operational alarm routes | `alarm_actions` stays empty until the routes exist |
| Other inference functions | Further calls of this module | Each needs its own queue, role and prefix |

## Usage

Use the latest released tag in place of `v1.0.0`.

```hcl
module "inference_function" {
  source = "git::https://github.com/aromapacifico-devops/terraform-aws-inference-function.git?ref=v1.0.0"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  data_key_arn    = module.security.data_key_arn
  objects_key_arn = module.security.objects_key_arn
  role_arns = {
    function = module.security.focus_function_role_arn
    delivery = module.security.focus_delivery_role_arn
  }

  names             = local.inference_names
  mission_type      = "FOCUS_CONFIRMATION"
  object_prefix     = "focus/"
  restricted_prefix = "restricted/"
  bedrock_model_id  = "us.amazon.nova-2-lite-v1:0"
  function_package  = { path = data.archive_file.functions["placeholder"].output_path }

  force_destroy_data = var.force_destroy_data
}
```

The root builds the names and gives the same ARNs to the security module, so the roles name the queue, bucket, table, bus and rule this module creates.

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `client`, `project`, `environment` | `string` | Yes | Codes for names and tags. `environment` is `dev`, `test` or `prod` |
| `additional_tags` | `map(string)` | No | Tags added on top of the provider default tags |
| `data_key_arn` | `string` | Yes | Key of the case table, both queues and the log group |
| `objects_key_arn` | `string` | Yes | Key of the flight object bucket |
| `role_arns` | `object` | Yes | `function`, the role of the function, and `delivery`, the role the rule uses to reach the work queue. They must differ |
| `names` | `object` | Yes | `event_bus`, `rule`, `work_queue`, `dead_letter_queue`, `function`, `objects_bucket`, `cases_table`, `errors_alarm` and `dead_letter_alarm`, built by the root. The bus cannot be `default` |
| `mission_type` | `string` | Yes | Mission type of the records the function processes, such as `FOCUS_CONFIRMATION` |
| `object_prefix` | `string` | Yes | Prefix the function reads, ending with `/` |
| `restricted_prefix` | `string` | Yes | Prefix that receives objects with a person. It may not contain the object prefix or sit inside it |
| `bedrock_model_id` | `string` | Yes | Model or inference profile the function invokes |
| `function_package` | `object` | Yes | `path` to a `.zip`, with optional `handler` (default `main.handler`) and `runtime` (default `python3.13`) |
| `processing` | `object` | No | Limits of the function and its queues, in the table below |
| `alarm_actions` | `list(string)` | No | ARNs notified by both alarms. Defaults to none |
| `force_destroy_data` | `bool` | No | Lets a destroy remove flight objects and the case table. Defaults to `false` |

| `processing` field | Default | Allowed |
|---|---:|---|
| `timeout_seconds` | 300 | 1 to 900 |
| `memory_mb` | 256 | 128 to 10,240 |
| `batch_size` | 1 | 1 to 10 |
| `maximum_concurrency` | 2 | 2 to 1,000 |
| `max_receive_count` | 4 | 1 to 1,000 |
| `visibility_timeout_seconds` | 1,800 | At least six times the timeout, at most 43,200 |
| `dead_letter_retention_seconds` | 1,209,600 | 60 to 1,209,600 |

## Outputs

| Name | Description |
|---|---|
| `event_bus_arn` | ARN of the platform bus |
| `event_bus_name` | Name of the platform bus, where the mission link publishes |
| `rule_arn` | ARN of the rule |
| `work_queue_arn` | ARN of the work queue |
| `dead_letter_queue_arn` | ARN of the dead letter queue |
| `function_arn` | ARN of the function |
| `object_bucket_arn` | ARN of the flight object bucket |
| `case_table_arn` | ARN of the case table |
| `alarm_arns` | ARNs of the alarms, keyed `errors` and `dead_letter` |

## Design choices

**A published flight record starts the function.** An object upload proves only that one file arrived. A photo can land while the flight log or another mandatory object is still missing, so a function started by raw S3 events could analyze an incomplete flight. The mission link publishes the record after its completion check, and the rule listens only for that event. The bucket therefore sends no event notifications.

**A queue between the rule and the function.** The queue separates delivery from processing. EventBridge only has to reach the queue, the function works at its own pace, and a failed record waits in the queue for its next attempt. Direct delivery from the rule to the function was discarded because it mixes delivery failures with processing failures and leaves no single place to cap concurrency.

**Its own bus.** Platform events stay apart from the AWS service events of the account default bus, and the function role can publish only to that one bus and only the `inference.completed` detail type. A bus has no charge of its own.

**One flight per batch.** Each message is a whole flight of about 50 photos, so a batch of one keeps a slow flight from holding others back. The 300-second timeout leaves about six seconds per photo for the person filter and the model call, and the visibility timeout is six times the function timeout, as the Lambda guide for SQS recommends. Two pollers is the lowest cap the mapping accepts and fits the account limit of 10 concurrent executions.

**Function settings stay configurable.** Retry counts, timeouts and retention live in `processing`, so the consolidated failure policy can change them in each environment with no change to the module.

**Data protection.** Versioning keeps every object version a flight record names, and the case table keeps deletion protection and point-in-time recovery. `force_destroy_data` turns both protections off together, for a demonstration environment that comes down when work stops.

## What happens when it fails

| Situation | What the platform does | Case state |
|---|---|---|
| An object arrives before the flight is complete | No record is published, so no message reaches the queue | Unchanged |
| The rule cannot reach the queue | EventBridge retries the delivery with its default retry policy | Unchanged |
| The function fails on a record | The message becomes visible again after the visibility timeout and the error alarm fires | Unchanged |
| A record fails on every receive | After the fourth receive SQS moves it to the dead letter queue, and the dead letter alarm fires | Unchanged, the reviewer works from the stored photos |
| The same record arrives twice | The function finds the stored result through its idempotency key and writes no second result | Unchanged |

A failure never deletes the source objects or changes a result already written. The function writes each result with a conditional put on its idempotency key, and its role holds no permission to update an item.

## Cost

The module has no hourly charge apart from the two alarms. Rates are from the AWS Price List API for us-east-1.

| Item | Rate | Pilot estimate |
|---|---|---|
| CloudWatch alarms | USD 0.10 per alarm a month, standard resolution | USD 0.20 a month per environment while it is up |
| Custom events on the bus | USD 1.00 per million events | Below USD 0.01 a month for about 60 confirmation flights |
| SQS, Lambda, DynamoDB and S3 | Per request and per stored GB | A few cents a month at pilot volume |
| Bedrock and Rekognition | Per image | About USD 1.75 per 1,000 images together |

## Pending confirmations

| Item | Current choice | If it is wrong |
|---|---|---|
| Field that carries the mission type | The rule matches `detail.mission_type` of `flight.record.published` and filters no source | The pattern adds the field or source the mission link fixes |
| Retry and timeout values | The defaults of `processing` | The roots pass other values in `processing` |
| Rekognition reading an exact encrypted version | The function role holds get object version and decrypt on its prefix | The first call in the development environment fails with an access error, and the role gains the missing action |

## Develop and test

The exact Terraform version lives in `.terraform-version`. Tests run against a mocked provider, so they need no AWS account and spend no credits.

```bash
terraform init -backend=false
terraform test
terraform -chdir=sample init -backend=false
terraform -chdir=sample validate
```

`terraform validate` runs on `sample/` because this module declares the `aws.project` provider alias, which only receives a provider from a caller.

The shared checks of the organization cover format, tests, TFLint, Checkov and secret scanning. An accepted finding goes in `docs/iac-exceptions.md` with its reason and its end condition.

## Versions

Commits follow Conventional Commits, and they decide the next version. A `fix` raises the patch, a `feat` raises the minor, and a breaking change raises the major. Each release publishes an exact `vX.Y.Z` tag and updates `CHANGELOG.md`. Consumers pin that tag, so a new version reaches an environment only through a reviewed change in the infrastructure repository.

## Related repositories

| Repository | Role |
|---|---|
| [`aromapacifico-devops-infra`](https://github.com/aromapacifico-devops/aromapacifico-devops-infra) | Roots of each environment, which consume this module |
| [`terraform-aws-security`](https://github.com/aromapacifico-devops/terraform-aws-security) | Keys, the function role and the delivery role |
| [`terraform-aws-module-template`](https://github.com/aromapacifico-devops/terraform-aws-module-template) | Template this repository was generated from |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents |
