resource "aws_iam_role" "ec2_role" {
  name = "${var.environment}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.environment}-ec2-policy"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-app-backup-demo",
          "arn:aws:s3:::my-app-backup-demo/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "web" {
  name_prefix = "${var.environment}-web-"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name        = "${var.environment}-web-sg"
    Environment = var.environment
    Project     = "Demo"
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "${var.environment}-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  user_data     = base64encode(templatefile("${path.module}/user_data.sh.tpl", {}))
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-web"
      Environment = var.environment
      Project     = "Demo"
    }
  }
  depends_on = [aws_security_group.web, aws_iam_instance_profile.ec2_profile]
}

resource "aws_autoscaling_group" "web" {
  vpc_zone_identifier = var.subnet_ids
  desired_capacity    = 2
  min_size           = 1
  max_size           = 3
  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
  health_check_type         = "EC2"
  health_check_grace_period = 300
  lifecycle {
    create_before_destroy = true
  }
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = "Demo"
    propagate_at_launch = true
  }
  tag {
    key                 = "Name"
    value               = "${var.environment}-web"
    propagate_at_launch = true
  }
  depends_on = [aws_launch_template.web, aws_iam_instance_profile.ec2_profile]
}