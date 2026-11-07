# Infrastructure code exceptions

A finding of the automated checks is accepted only through a row in this table, added in its own reviewed pull request. Each row states why the finding is acceptable and the condition that ends the exception.

| Rule | Path | Resource | Reason | Expires when |
|---|---|---|---|---|
| Lifecycle protection | `main.tf` | Case table and object bucket | `prevent_destroy` cannot depend on a variable and would block the destroy that protects the credits. Deletion protection and `force_destroy`, driven by `force_destroy_data`, keep the data of the pilot protected | The platform leaves the credit accounts |
