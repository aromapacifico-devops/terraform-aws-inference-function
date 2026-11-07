# Sample

Smallest working call of this module, and the reference for how a root injects IDs and names. It uses local state and the values in `terraform.tfvars`.

```bash
terraform init -backend=false
terraform validate
terraform plan
```

`terraform plan` needs AWS credentials. Set `deploy_role_arn` to assume a role, or leave it empty to use the local credentials.
