# Oldest Terraform and provider versions this module supports. The consuming root sets the exact ones.
terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.0"
      configuration_aliases = [aws.project]
    }
  }
}
