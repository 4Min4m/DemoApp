#!/bin/bash
set -ex
echo "Starting user data script" | tee -a /var/log/user-data.log

# Stop any existing web servers
systemctl stop httpd || true
systemctl stop kestrel || true
pkill -f "dotnet" || true

# Install packages
yum update -y --skip-broken | tee -a /var/log/user-data.log
yum install -y nginx aws-cli amazon-ssm-agent | tee -a /var/log/user-data.log

# Start SSM agent
systemctl start amazon-ssm-agent | tee -a /var/log/user-data.log
systemctl enable amazon-ssm-agent | tee -a /var/log/user-data.log

# Verify AWS CLI
echo "Checking AWS CLI version" | tee -a /var/log/user-data.log
aws --version | tee -a /var/log/user-data.log

# Configure AWS CLI region
echo "Configuring AWS CLI region" | tee -a /var/log/user-data.log
mkdir -p /root/.aws
echo -e "[default]\nregion = us-east-1" > /root/.aws/config

# Create web directory
mkdir -p /usr/share/nginx/html | tee -a /var/log/user-data.log

# Download index.html from S3
echo "Downloading index.html from S3" | tee -a /var/log/user-data.log
aws s3 cp s3://my-app-backup-demo/index.html /usr/share/nginx/html/index.html 2>&1 | tee -a /var/log/user-data.log
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to download index.html from S3" | tee -a /var/log/user-data.log
  exit 1
fi

# Set permissions
chmod 644 /usr/share/nginx/html/index.html | tee -a /var/log/user-data.log
chown nginx:nginx /usr/share/nginx/html/index.html | tee -a /var/log/user-data.log

# Configure Nginx
echo "Creating nginx configuration" | tee -a /var/log/user-data.log
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
nginx -t 2>&1 | tee -a /var/log/user-data.log || exit 1

# Start Nginx
systemctl start nginx | tee -a /var/log/user-data.log
systemctl enable nginx | tee -a /var/log/user-data.log

# Configure firewall
if [ -x "$(command -v firewall-cmd)" ]; then
  firewall-cmd --permanent --zone=public --add-service=http | tee -a /var/log/user-data.log
  firewall-cmd --reload | tee -a /var/log/user-data.log
fi

# Restart Nginx
systemctl restart nginx | tee -a /var/log/user-data.log

# Verify locally
curl -s http://localhost 2>&1 | tee -a /var/log/user-data.log || exit 1
echo "Setup complete" | tee -a /var/log/user-data.log