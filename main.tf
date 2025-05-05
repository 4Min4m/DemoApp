provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket         = "my-terraform-state-demo"
    key            = "demo/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}

module "vpc" {
  source      = "./modules/vpc"
  environment = var.environment
  cidr_block  = "10.0.0.0/16"
}

module "ec2" {
  source        = "./modules/ec2"
  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.subnet_ids
  ami_id        = "ami-0c55b159cbfafe1f0"
  instance_type = var.environment == "prod" ? "t3.medium" : "t2.micro"
}

resource "aws_s3_bucket" "backup" {
  bucket = "my-app-backup-demo"
  tags = {
    Name        = "${var.environment}-backup"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_s3_object" "index_html" {
  bucket = aws_s3_bucket.backup.bucket
  key    = "index.html"
  source = "app/index.html"
  content_type = "text/html"
}

resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name        = "terraform-locks"
    Environment = var.environment
    Project     = "Demo"
  }
}