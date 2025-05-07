#!/bin/bash
set -ex
echo "Starting user data script" | tee -a /var/log/user-data.log

# Stop any existing web servers
systemctl stop httpd 2>/dev/null || true
systemctl stop nginx 2>/dev/null || true
systemctl stop kestrel 2>/dev/null || true
pkill -f "dotnet" 2>/dev/null || true

# Install packages
dnf update -y | tee -a /var/log/user-data.log
dnf install -y nginx aws-cli amazon-ssm-agent | tee -a /var/log/user-data.log

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

# Test S3 access
echo "Testing S3 access" | tee -a /var/log/user-data.log
aws s3 ls s3://my-app-backup-demo/ 2>&1 | tee -a /var/log/user-data.log
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to access S3 bucket" | tee -a /var/log/user-data.log
fi

# Create web directory and ensure permissions
mkdir -p /usr/share/nginx/html | tee -a /var/log/user-data.log
chown -R nginx:nginx /usr/share/nginx/html | tee -a /var/log/user-data.log

# Create a simple index.html if download fails
echo "Creating backup index.html" | tee -a /var/log/user-data.log
cat > /usr/share/nginx/html/index.html << 'HTMLCONTENT'
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
HTMLCONTENT

# Set permissions
chmod 644 /usr/share/nginx/html/index.html | tee -a /var/log/user-data.log
chown nginx:nginx /usr/share/nginx/html/index.html | tee -a /var/log/user-data.log

# Download index.html from S3
echo "Downloading index.html from S3" | tee -a /var/log/user-data.log
aws s3 cp s3://my-app-backup-demo/index.html /usr/share/nginx/html/index.html 2>&1 | tee -a /var/log/user-data.log
if [ $? -ne 0 ]; then
  echo "WARNING: Failed to download index.html from S3, using backup file" | tee -a /var/log/user-data.log
fi

# Set permissions again after potential S3 download
chmod 644 /usr/share/nginx/html/index.html | tee -a /var/log/user-data.log
chown nginx:nginx /usr/share/nginx/html/index.html | tee -a /var/log/user-data.log

# Configure Nginx server configuration
echo "Creating nginx server configuration" | tee -a /var/log/user-data.log
cat > /etc/nginx/conf.d/default.conf << 'NGINXCONF'
server {
    listen 80 default_server;
    server_name _;
    error_log /var/log/nginx/error.log debug;
    access_log /var/log/nginx/access.log;
    
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINXCONF

# Test Nginx config
echo "Testing nginx configuration" | tee -a /var/log/user-data.log
nginx -t 2>&1 | tee -a /var/log/user-data.log
if [ $? -ne 0 ]; then
  echo "ERROR: Nginx configuration test failed" | tee -a /var/log/user-data.log
  cat /var/log/nginx/error.log | tee -a /var/log/user-data.log
fi

# Configure SELinux if present
if [ -x "$(command -v setsebool)" ]; then
  echo "Configuring SELinux" | tee -a /var/log/user-data.log
  setsebool -P httpd_can_network_connect 1 | tee -a /var/log/user-data.log || true
fi

# Configure firewall
if [ -x "$(command -v firewall-cmd)" ]; then
  echo "Configuring firewall" | tee -a /var/log/user-data.log
  firewall-cmd --permanent --zone=public --add-service=http | tee -a /var/log/user-data.log || true
  firewall-cmd --reload | tee -a /var/log/user-data.log || true
fi

# Update permissions for nginx directories
echo "Setting directory permissions" | tee -a /var/log/user-data.log
chmod 755 /var/log/nginx
chown -R nginx:nginx /var/log/nginx

# Restart Nginx
echo "Starting nginx service" | tee -a /var/log/user-data.log
systemctl enable nginx | tee -a /var/log/user-data.log
systemctl restart nginx | tee -a /var/log/user-data.log

# Check nginx status
echo "Checking nginx status" | tee -a /var/log/user-data.log
systemctl status nginx | tee -a /var/log/user-data.log

# List listening ports
echo "Checking listening ports" | tee -a /var/log/user-data.log
ss -tulpn | grep LISTEN | tee -a /var/log/user-data.log

# Verify locally
echo "Testing local web server" | tee -a /var/log/user-data.log
curl -v http://localhost 2>&1 | tee -a /var/log/user-data.log

echo "Setup complete" | tee -a /var/log/user-data.log