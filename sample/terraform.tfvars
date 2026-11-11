# Sample values. No identifiers of real resources and no secrets.
client      = "fnc"
project     = "aroma"
environment = "dev"
region      = "us-east-1"

common_tags = {
  Client      = "fnc"
  Project     = "aroma"
  Environment = "dev"
  Owner       = "platform"
  CostCenter  = "pruebas"
  ManagedBy   = "Terraform"
}

# Nova 2 Lite through the US cross-Region inference profile.
bedrock_model_id = "us.amazon.nova-2-lite-v1:0"

# Placeholder package that only answers with no failures.
function_package_path = "../tests/fixtures/function.zip"
