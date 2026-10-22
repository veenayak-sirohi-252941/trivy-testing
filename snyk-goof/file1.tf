terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.2.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "bucket1" {
  bucket = "bucket1"

  tags = {
    Name        = "bucket1"
    Environment = "Dev1"
  }
}

resource "aws_s3_bucket" "gegegege" {
  bucket = "ffefgege"

  tags = {
    Name        = "bucdadaket2"
    Environment = "Dev2"
  }
}
