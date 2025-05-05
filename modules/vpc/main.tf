resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_subnet" "subnet_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 1)
  availability_zone = "us-east-1a"
  tags = {
    Name        = "${var.environment}-subnet-a"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_subnet" "subnet_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 2)
  availability_zone = "us-east-1b"
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

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name        = "${var.environment}-rt"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.main.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.main.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = [aws_route_table.main.id]
  tags = {
    Name        = "${var.environment}-s3-endpoint"
    Environment = var.environment
    Project     = "Demo"
  }
}