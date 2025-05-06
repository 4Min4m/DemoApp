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
      }
    ]
  })
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
  user_data     = base64encode(<<-EOF
                  #!/bin/bash
                  set -ex  # Add -x for verbose logging
                  
                  # Update system and install required packages
                  yum update -y --skip-broken
                  yum install -y nginx aws-cli
                  
                  # Start and enable Nginx
                  systemctl start nginx
                  systemctl enable nginx
                  
                  # Create a temporary file directly in case S3 download fails
                  cat > /usr/share/nginx/html/index.html << 'INDEXFILE'
                  <!DOCTYPE html>
                  <html>
                  <head>
                    <title>Demo App</title>
                  </head>
                  <body>
                    <h1>Welcome to the Demo App</h1>
                    <p>Version: 1.0</p>
                  </body>
                  </html>
                  INDEXFILE
                  
                  # Attempt S3 download as original plan
                  aws s3 cp s3://my-app-backup-demo/index.html /usr/share/nginx/html/index.html || echo "S3 download failed, using default file"
                  
                  # Ensure proper permissions
                  chmod 644 /usr/share/nginx/html/index.html
                  
                  # Open firewall if needed (for Amazon Linux 2)
                  if [ -x "$(command -v firewall-cmd)" ]; then
                    firewall-cmd --permanent --zone=public --add-service=http
                    firewall-cmd --reload
                  fi
                  
                  # Final restart of Nginx
                  systemctl restart nginx
                  
                  # Verify Nginx is running
                  systemctl status nginx
                  curl -s http://localhost
                  
                  echo "Setup complete"
                  EOF
  )
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
  depends_on = [aws_launch_template.web, aws_iam_instance_profile.ec2_profile]
}