#!/bin/bash
set -e

# Install AWS CLI
dnf update -y
dnf install -y aws-cli

echo "Checking AWS CLI version" >> /var/log/user-data.log
aws --version >> /var/log/user-data.log

echo "Checking available buckets" >> /var/log/user-data.log
aws s3 ls >> /var/log/user-data.log 2>&1

echo "Checking bucket contents" >> /var/log/user-data.log
aws s3 ls s3://my-app-backup-demo-${bucket_suffix}/ >> /var/log/user-data.log 2>&1

# Also check instance metadata for the role
echo "Checking instance role" >> /var/log/user-data.log
curl http://169.254.169.254/latest/meta-data/iam/info >> /var/log/user-data.log 2>&1

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

echo "Bucket suffix is: ${bucket_suffix}" >> /var/log/user-data.log

echo "Setup complete" >> /var/log/user-data.log