#!/bin/bash
set -e

# Stop any existing web servers
systemctl stop httpd 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
systemctl stop kestrel 2>/dev/null || true
pkill -f "dotnet" 2>/dev/null || true

# Install packages
dnf update -y
dnf install -y nginx aws-cli amazon-ssm-agent

# Start SSM agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Configure AWS CLI region
mkdir -p /root/.aws
echo -e "[default]\nregion = us-east-1" > /root/.aws/config

# Create web directory and ensure permissions
mkdir -p /usr/share/nginx/html
chown -R nginx:nginx /usr/share/nginx/html

# Download index.html from S3
echo "Attempting to download index.html from S3" > /var/log/user-data.log
aws s3 cp s3://my-app-backup-demo-${var.bucket_suffix}/index.html /usr/share/nginx/html/index.html 2>> /var/log/user-data.log
if [ $? -eq 0 ]; then
  echo "Successfully downloaded index.html from S3" >> /var/log/user-data.log
else
  echo "Failed to download index.html from S3, exiting" >> /var/log/user-data.log
  exit 1
fi

# Set permissions
chmod 644 /usr/share/nginx/html/index.html
chown nginx:nginx /usr/share/nginx/html/index.html

# Create nginx server configuration
cat > /etc/nginx/conf.d/default.conf << 'NGINXCONF'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINXCONF

# Test Nginx config
nginx -t

# Configure SELinux if present
if [ -x "$(command -v setsebool)" ]; then
  setsebool -P httpd_can_network_connect 1 || true
fi

# Configure firewall if present
if [ -x "$(command -v firewall-cmd)" ]; then
  firewall-cmd --permanent --zone=public --add-service=http || true
  firewall-cmd --reload || true
fi

# Update permissions for nginx directories
chmod 755 /var/log/nginx
chown -R nginx:nginx /var/log/nginx

# Start Nginx
systemctl enable nginx
systemctl restart nginx

echo "Setup complete" >> /var/log/user-data.log