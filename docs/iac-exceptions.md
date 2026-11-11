# Infrastructure code exceptions

A finding of the automated checks is accepted only through a row in this table, added in its own reviewed pull request. Each row states why the finding is acceptable and the condition that ends the exception.

| Rule | Path | Resource | Reason | Expires when |
|---|---|---|---|---|
| Lifecycle protection | `main.tf` | Case table and object bucket | `prevent_destroy` cannot depend on a variable and would block the destroy that protects the credits. Deletion protection and `force_destroy`, driven by `force_destroy_data`, keep the data of the pilot protected | The platform leaves the credit accounts |
| CKV2_AWS_62, S3 event notifications | `main.tf` | Object bucket | The function starts from the published flight record, because a raw object event can arrive before the flight is complete | Never, while the completion check publishes the record |
| CKV_AWS_18, S3 access logging | `main.tf` | Object bucket | Object deliveries are recorded as S3 data events in the audit trail of the mission link, which keeps them five years | The audit trail stops recording object data events |
| CKV_AWS_144, cross-Region replication | `main.tf` | Object bucket | The pilot runs in one Region, and a replica would double object storage with no recovery target that needs it | A recovery objective requires a second Region |
| CKV_AWS_338, log retention of one year | `main.tf` | Function log group | Logs keep 30 days, like the other functions of the platform, since lasting evidence lives in the case table and the audit trail | Operations require longer log retention |
| CKV_AWS_116, Lambda dead letter queue | `main.tf` | Function | The function is invoked through an event source mapping, so failed records reach the dead letter queue of the work queue through its redrive policy. A Lambda dead letter queue applies only to asynchronous invocations | The function gains an asynchronous trigger |
| CKV_AWS_115, reserved concurrency | `main.tf` | Function | The account allows 10 concurrent executions, which leaves no room to reserve. The event source mapping caps the function at two pollers | The account concurrency quota rises |
| CKV_AWS_117, function in a VPC | `main.tf` | Function | The function calls only regional AWS APIs. A VPC would need interface endpoints for Bedrock, Rekognition, SQS, DynamoDB, EventBridge and S3, each with an hourly charge | Private access to those services becomes a requirement |
| CKV_AWS_173, environment variables under a customer key | `main.tf` | Function | The variables hold names, prefixes and a model identifier, never a secret, and Lambda encrypts them at rest with its service key | A secret is passed as an environment variable |
| CKV_AWS_272, code signing | `main.tf` | Function | Packages are built from the reviewed repository by the pipeline that deploys them, and no signing profile exists yet | A signing profile exists for the platform functions |
| CKV_AWS_50, X-Ray tracing | `main.tf` | Function | Traces are not part of the current observability design, and the function role holds no trace permission | The observability design adds traces for the functions |
