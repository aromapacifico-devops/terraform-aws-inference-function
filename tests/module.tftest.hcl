# Plan-time tests against a mocked provider. They need no AWS account.
mock_provider "aws" {
  alias = "project"
}

variables {
  client      = "fnc"
  project     = "aroma"
  environment = "test"
}

run "accepts_valid_governance_values" {
  command = plan

  providers = {
    aws.project = aws.project
  }
}

run "rejects_an_unknown_environment" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}

run "rejects_an_invalid_client_code" {
  command = plan

  providers = {
    aws.project = aws.project
  }

  variables {
    client = "FNC"
  }

  expect_failures = [var.client]
}
