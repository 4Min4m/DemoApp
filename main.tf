provider "aws" {
  region = "us-east-1"
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
  subnet_ids    = module.vpc.public_subnet_ids
  ami_id        = "ami-08b9ea139541d36ab"
  instance_type = "t2.micro"
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
  bucket       = aws_s3_bucket.backup.bucket
  key          = "index.html"
  source       = "app/index.html"
  content_type = "text/html"
}