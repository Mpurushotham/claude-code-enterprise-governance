terraform {
  required_version = ">= 1.7"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.60" } }
  # backend "s3" { ... }  # landing-zone standard backend
}
provider "aws" { region = var.region }
