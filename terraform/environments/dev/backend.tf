terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state (recommended for real use). Swap the bucket/table names
  # for your own, or comment this block out to use local state while
  # experimenting. Kept as an example rather than wired to a real bucket so
  # `terraform init` doesn't require pre-existing infrastructure.
  #
  # backend "s3" {
  #   bucket         = "tripare-terraform-state"
  #   key            = "dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "tripare-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "tripare"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}
