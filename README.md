# terraform-aws-inference-function

Pattern of one event-driven inference function for the Aroma Pacifico platform, applied to focus confirmation. A drone image lands in S3, an event starts the function, the function analyzes the image and writes the result in the case table. The other functions of the design repeat this pattern with their own trigger and prefix. It implements box C08 of the implementation scope.

This repository holds the skeleton and the interface the module commits to. The resources arrive with the first release, and no version tag exists yet.

## The four pieces of the pattern

| Piece | How it is built here |
|---|---|
| Trigger | An EventBridge rule on objects created under one bucket prefix |
| Read permission | The function reads that prefix only |
| Write permission | The function writes to the case table only |
| Inference permission | The function detects labels with Rekognition and invokes one Bedrock model |

Rekognition only filters people, and Bedrock performs the analysis. Both are managed services, so this module calls them and creates neither.

## What it creates

| Resource | Purpose |
|---|---|
| S3 bucket | Drone objects, encrypted with the objects key |
| EventBridge rule and target | Starts the function on each new object |
| Lambda function | Runs the deployment package |
| Lambda permission | Lets EventBridge invoke the function |
| Dead letter queue | Keeps events the function could not process |
| CloudWatch alarm | Reports failed invocations |
| Case table | Stores results, encrypted with the data key |

The function code stays out of this module. It receives a deployment package, since the project builds no application logic.

## What it leaves to other modules

The function role and the encryption keys come from the security module. The role holds the permissions of the table above, so this module creates no identity and no network.

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

  data_key_arn      = module.security.data_key_arn
  objects_key_arn   = module.security.objects_key_arn
  function_role_arn = module.security.focus_function_role_arn

  names                 = local.inference_names
  object_prefix         = var.focus_object_prefix
  bedrock_model_id      = var.bedrock_model_id
  function_package_path = var.focus_package_path
  force_destroy_data    = var.force_destroy_data
}
```

## Inputs

| Name | Type | Required | Description |
|---|---|---|---|
| `client`, `project`, `environment`, `additional_tags` | Governance | See below | Codes for tags and the extra tags of the module. `additional_tags` is optional |
| `data_key_arn` | `string` | Yes | Key of the case table |
| `objects_key_arn` | `string` | Yes | Key of the object bucket |
| `function_role_arn` | `string` | Yes | Role of the function |
| `names` | `object` | Yes | Final names of the resources, built by the root |
| `object_prefix` | `string` | Yes | Bucket prefix that starts the function |
| `bedrock_model_id` | `string` | Yes | Model the function invokes |
| `function_package_path` | `string` | Yes | Deployment package of the function |
| `force_destroy_data` | `bool` | No | Lets a destroy remove data. Defaults to `false`, and the production environment of the pilot keeps it off |

## Outputs

| Name | Description |
|---|---|
| `function_arn` | ARN of the function |
| `object_bucket_arn` | ARN of the object bucket |
| `case_table_arn` | ARN of the case table |
| `dead_letter_queue_arn` | ARN of the dead letter queue |
| `alarm_arn` | ARN of the failure alarm |

## What happens when it fails

An invocation that fails retries, and an event that keeps failing moves to the dead letter queue, which raises the alarm. The object stays in the bucket and the case keeps its state, so a failure never changes a result that was already written.

## Cost

The module has no hourly charge. Testing with real images adds about USD 1.75 per 1,000 images for Bedrock and Rekognition together.

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
| [`terraform-aws-module-template`](https://github.com/aromapacifico-devops/terraform-aws-module-template) | Template this repository was generated from |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents |
