terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "morays-terraform-state"
    key            = "morays-upgrade-ha/terraform.tfstate"
    region         = "eu-west-2"
  }
}

# A separate local state is used for this new learning project.
# Do not reuse the S3 backend key of your existing Terraform projects.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}