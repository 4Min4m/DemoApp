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
  user_data     = base64encode(<<-EOF
                  #!/bin/bash
                  exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
                  echo "Starting user data script execution"
                  date
                  
                  # Update system and install required packages
                  echo "Installing packages"
                  yum update -y --skip-broken
                  yum install -y nginx aws-cli amazon-ssm-agent
                  
                  # Start SSM agent
                  echo "Starting SSM agent"
                  systemctl start amazon-ssm-agent
                  systemctl enable amazon-ssm-agent
                  
                  # Configure nginx defaults
                  echo "Configuring Nginx"
                  mkdir -p /usr/share/nginx/html
                  
                  # Default content in case S3 download fails
                  echo '<!DOCTYPE html><html><head><title>Demo App</title></head><body><h1>Welcome to the Demo App</h1><p>Version: 1.0</p></body></html>' > /usr/share/nginx/html/index.html
                  
                  # Download index.html from S3
                  echo "Downloading index.html from S3"
                  aws s3 cp s3://my-app-backup-demo/index.html /usr/share/nginx/html/index.html --region us-east-1
                  
                  # Check if download was successful
                  if [ $? -ne 0 ]; then
                    echo "WARNING: Failed to download index.html from S3. Using default."
                  else
                    echo "Successfully downloaded index.html from S3"
                  fi
                  
                  # Set appropriate permissions
                  echo "Setting permissions"
                  chmod 644 /usr/share/nginx/html/index.html
                  chown nginx:nginx /usr/share/nginx/html/index.html
                  
                  # Create a more explicit nginx configuration
                  echo "Creating nginx configuration"
                  cat > /etc/nginx/conf.d/default.conf << 'NGINXCONF'
                  server {
                      listen 80;
                      server_name _;
                      root /usr/share/nginx/html;
                      index index.html;
                      location / {
                          try_files $uri $uri/ =404;
                      }
                  }
                  NGINXCONF
                  
                  # Test nginx configuration
                  echo "Testing nginx configuration"
                  nginx -t
                  
                  # Start and enable nginx
                  echo "Starting nginx"
                  systemctl start nginx
                  systemctl enable nginx
                  
                  # Configure firewall if it exists
                  if [ -x "$(command -v firewall-cmd)" ]; then
                    echo "Configuring firewall"
                    firewall-cmd --permanent --zone=public --add-service=http
                    firewall-cmd --reload
                  fi
                  
                  # Restart nginx and verify it's running
                  echo "Restarting nginx"
                  systemctl restart nginx
                  systemctl status nginx
                  
                  # Verify website content
                  echo "Content of index.html:"
                  cat /usr/share/nginx/html/index.html
                  
                  # Test HTTP locally
                  echo "Testing HTTP locally"
                  curl -v http://localhost
                  
                  # Check nginx logs for any issues
                  echo "Nginx error log:"
                  cat /var/log/nginx/error.log
                  
                  echo "Setup complete"
                  date
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