provider "aws" {
  region = "us-east-1"
}

provider "random" {}

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
  ami_id        = "ami-0f88e80871fd81e91"
  instance_type = "t2.micro"
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "backup" {
  bucket = "my-app-backup-demo-${random_string.bucket_suffix.result}"
  tags = {
    Name        = "${var.environment}-backup"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_s3_bucket_ownership_controls" "backup_ownership" {
  bucket = aws_s3_bucket.backup.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  depends_on = [aws_s3_bucket_ownership_controls.backup_ownership]
}

resource "aws_s3_bucket_policy" "allow_ec2_access" {
  bucket = aws_s3_bucket.backup.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = module.ec2.instance_role_arn
        }
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource  = [
          "${aws_s3_bucket.backup.arn}",
          "${aws_s3_bucket.backup.arn}/*"
        ]
      }
    ]
  })
  depends_on = [aws_s3_bucket_public_access_block.public_access]
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.backup.id
  key          = "index.html"
  source       = "app/index.html"
  content_type = "text/html"
  acl          = "public-read"
  depends_on = [aws_s3_bucket_public_access_block.public_access]
}