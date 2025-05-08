#!/bin/bash
set -e

# Install AWS CLI and SSM Agent
dnf update -y
dnf install -y aws-cli amazon-ssm-agent

# Start SSM agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Configure AWS CLI region
mkdir -p /root/.aws
echo -e "[default]\nregion = us-east-1" > /root/.aws/config

# Create directory and ensure permissions
mkdir -p /usr/share/html
chmod 755 /usr/share/html

# Download index.html from S3
echo "Attempting to download index.html from S3" > /var/log/user-data.log
aws s3 cp s3://my-app-backup-demo-${bucket_suffix}/index.html /usr/share/html/index.html 2>> /var/log/user-data.log
if [ $? -eq 0 ]; then
  echo "Successfully downloaded index.html from S3" >> /var/log/user-data.log
else
  echo "Failed to download index.html from S3, exiting" >> /var/log/user-data.log
  exit 1
fi

# Set permissions
chmod 644 /usr/share/html/index.html

echo "Setup complete" >> /var/log/user-data.log