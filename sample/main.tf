# Calls the module from the parent directory.
module "this" {
  source = "../"

  providers = {
    aws.project = aws.principal
  }

  client      = var.client
  project     = var.project
  environment = var.environment

  data_key_arn    = data.aws_kms_alias.keys["data"].target_key_arn
  objects_key_arn = data.aws_kms_alias.keys["objects"].target_key_arn
  role_arns       = { for purpose, role in data.aws_iam_role.roles : purpose => role.arn }

  names             = local.names
  mission_type      = "FOCUS_CONFIRMATION"
  object_prefix     = "focus/"
  restricted_prefix = "restricted/"
  bedrock_model_id  = var.bedrock_model_id
  function_package  = { path = var.function_package_path }

  force_destroy_data = true
}
