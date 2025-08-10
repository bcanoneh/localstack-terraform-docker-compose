terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_requesting_account_id  = true

  endpoints {
    s3       = "http://localstack:4566"
    sqs      = "http://localstack:4566"
    sns      = "http://localstack:4566"
    dynamodb = "http://localstack:4566"
  }

  s3_use_path_style = true
}


resource "aws_s3_bucket" "bucket" {
  bucket = "my-local-bucket"
}

resource "aws_sqs_queue" "queue" {
  name = "my-local-queue"
}
