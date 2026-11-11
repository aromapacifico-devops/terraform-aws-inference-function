# Data sources of the sample. They find the keys and roles that the security module created in the
# same environment, so that the values file holds no identifier.
data "aws_kms_alias" "keys" {
  for_each = toset(["data", "objects"])
  provider = aws.principal

  name = "alias/${local.name_prefix}-kms-${each.key}"
}

data "aws_iam_role" "roles" {
  for_each = local.role_names
  provider = aws.principal

  name = each.value
}
