# terraform-aws-module-template

Starting point for every reusable Terraform module of the Aroma Pacifico platform. A new module repository is generated from this template, so that all modules share one file layout, one set of governance inputs and one way to test and release. This repository is copied and never consumed, and it creates no infrastructure.

## Create a module

```bash
gh repo create aromapacifico-devops/terraform-aws-<name> \
  --template aromapacifico-devops/terraform-aws-module-template \
  --public --clone
```

Then complete these steps in the new repository.

1. Replace this README with the purpose, resources, inputs and outputs of the module.
2. Set the required reviewers in `.github/CODEOWNERS`.
3. Add the inputs, resources and outputs, and cover each validation in `tests/`.
4. Complete `sample/` so that it calls the module the way a root does.
5. Connect the shared workflows of the organization.

The name follows `terraform-aws-<name>`, which is the format the Terraform Registry expects, so a module can be published later with no change to its layout.

## What each file holds

| Path | Holds |
|---|---|
| `versions.tf` | Oldest Terraform and AWS provider versions the module supports, and the `aws.project` alias |
| `providers.tf` | A note only, since a module configures no provider |
| `variables.tf` | Inputs, each with a type, a description and a validation |
| `locals.tf` | Transformations of the inputs |
| `data.tf` | Computational data sources only |
| `main.tf` | Resources, each with `provider = aws.project` |
| `outputs.tf` | One attribute per output, each with a description |
| `tests/` | `terraform test` files against a mocked provider, which need no AWS account |
| `sample/` | Smallest working call of the module, with local state |
| `examples/` | Realistic uses that call the module by its version tag |
| `docs/iac-exceptions.md` | Accepted findings, each with its reason and its end condition |
| `CHANGELOG.md` | Changes per version |
| `.terraform-version` | Exact Terraform version used to develop and test |
| `.github/dependabot.yml` | Weekly update proposals for providers and actions |
| `.github/CODEOWNERS` | Required reviewers of each change |

## Rules every module follows

A module creates the resources of one capability and receives everything else as inputs. Networks, identities, encryption keys and security groups belong to their own modules, so a workload module asks for their identifiers. The root injects final resource names, which keeps the naming convention in one place.

| Subject | Rule |
|---|---|
| Names | `{client}-{project}-{environment}-{type}-{key}`, built by the root |
| Provider | Received as `aws.project`, set explicitly on each resource |
| Backend | None, since state belongs to the root |
| Secrets | None in variables, outputs, state or files |
| Lock file | Committed by the root only |
| Versions | Consumed through an exact `vX.Y.Z` tag |

## Test a module

```bash
terraform init -backend=false
terraform test
terraform -chdir=sample init -backend=false
terraform -chdir=sample validate
```

`terraform test` is the validation of the module itself. `terraform validate` fails on a module that declares a provider alias, because the alias only gets a provider from a caller, so the command runs on `sample/`.

## Related repositories

| Repository | Role |
|---|---|
| [`aromapacifico-devops-infra`](https://github.com/aromapacifico-devops/aromapacifico-devops-infra) | Roots of each environment, which consume the modules |
| [`.github`](https://github.com/aromapacifico-devops/.github) | Organization profile and shared workflows |
| [`aromapacifico-devops-docs`](https://github.com/aromapacifico-devops/aromapacifico-devops-docs) | Architecture and design documents |
