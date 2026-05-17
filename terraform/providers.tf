terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider — primary region (us-east-1)
provider "aws" {
  region = var.primary_region
}

# Aliased provider — secondary region (us-west-2)
# Resources that should live in us-west-2 reference this provider alias.
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}