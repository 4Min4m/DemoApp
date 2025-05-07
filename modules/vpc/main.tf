resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, 1)
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-subnet-a"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, 2)
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.environment}-subnet-b"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name        = "${var.environment}-igw"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name        = "${var.environment}-nat-eip"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.subnet_a.id
  tags = {
    Name        = "${var.environment}-nat"
    Environment = var.environment
    Project     = "Demo"
  }
  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name        = "${var.environment}-public-rt"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource  = [
          "arn:aws:s3:::my-app-backup-demo",
          "arn:aws:s3:::my-app-backup-demo/*"
        ]
      }
    ]
  })
  tags = {
    Name        = "${var.environment}-s3-endpoint"
    Environment = var.environment
    Project     = "Demo"
  }
  depends_on = [aws_route_table.public]
}

resource "aws_security_group" "vpc_endpoint" {
  name_prefix = "${var.environment}-vpc-endpoint-"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.environment}-vpc-endpoint-sg"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
  security_group_ids  = [aws_security_group.vpc_endpoint.id]
  private_dns_enabled = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["ssm:SendCommand", "ssm:GetCommandInvocation"]
        Resource  = "*"
      }
    ]
  })
  tags = {
    Name        = "${var.environment}-ssm-endpoint"
    Environment = var.environment
    Project     = "Demo"
  }
}