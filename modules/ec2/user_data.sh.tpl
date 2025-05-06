#!/bin/bash
set -ex
echo "Starting user data script"

# Install packages
yum update -y --skip-broken
yum install -y nginx aws-cli amazon-ssm-agent

# Start SSM agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Verify AWS CLI
echo "Checking AWS CLI version"
aws --version

# Configure AWS CLI region
echo "Configuring AWS CLI region"
mkdir -p /root/.aws
echo -e "[default]\nregion = us-east-1" > /root/.aws/config

# Create web directory
mkdir -p /usr/share/nginx/html

# Download index.html from S3
echo "Downloading index.html from S3"
aws s3 cp s3://my-app-backup-demo/index.html /usr/share/nginx/html/index.html
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to download index.html from S3"
  exit 1
fi

# Set permissions
chmod 644 /usr/share/nginx/html/index.html
chown nginx:nginx /usr/share/nginx/html/index.html

# Configure Nginx
echo "Creating nginx configuration"
cat > /etc/nginx/conf.d/default.conf << 'NGINXCONF'
server {
    listen 80 default_server;
    server_name _;
    error_log /var/log/nginx/error.log debug;
    root /usr/share/nginx/html;
    index index.html;
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINXCONF

# Test Nginx config
nginx -t || exit 1

# Start Nginx
systemctl start nginx
systemctl enable nginx

# Configure firewall
if [ -x "$(command -v firewall-cmd)" ]; then
  firewall-cmd --permanent --zone=public --add-service=http
  firewall-cmd --reload
fi

# Restart Nginx
systemctl restart nginx

# Verify locally
curl -s http://localhost || exit 1
echo "Setup complete"