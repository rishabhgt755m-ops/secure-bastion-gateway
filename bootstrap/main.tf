########################################
# Bootstrap: Terraform state backend
#
# Run this ONCE, on its own, before the main configuration.
# Its own state stays LOCAL and is not committed. See D-016 and D-017
# in bastion-decision-log.md for why this config sits outside the
# normal lifecycle.
#
# Usage:
#   cd bootstrap
#   terraform init
#   terraform apply
#
# Do not run terraform destroy in this directory. Destroying the
# bucket would delete the state of every other resource in the
# project.
########################################

provider "aws" {
  region = "ap-south-1"
}

# The bucket that holds state for the main configuration.
# S3 bucket names are globally unique across every AWS account,
# so this name is prefixed to avoid collision.
resource "aws_s3_bucket" "state" {
  bucket = "rishabh-bastion-tfstate-apsouth1"
}

# Versioning keeps previous copies of the state file, so a corrupted
# or accidentally overwritten state can be rolled back.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption. AES256 uses keys AWS manages (SSE-S3).
# KMS would give key control and an audit trail but costs money per
# request and adds a permissions layer, which is not worth it for a
# solo project's state bucket.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access sits above bucket policies and ACLs. Even if a
# future policy tried to grant public access, these four switches
# prevent it. State files contain secrets in plain text and this
# repository is public, so this is set explicitly rather than relying
# on the AWS default.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  value       = aws_s3_bucket.state.id
  description = "Pass this to the backend block in the main configuration."
}
