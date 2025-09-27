#!/bin/bash
set -e

# Configuration
APP_NAME="fastapi-fileserver"
APP_DIR="/var/www/fastapi-fileserver"
SERVICE_USER="www-data"
SERVICE_GROUP="www-data"

echo "🚀 Deploying FastAPI File Server to Hostinger VPS..."

# Check if running as root or with sudo access
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

# Navigate to app directory
cd $APP_DIR

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv venv
    chown -R $SERVICE_USER:$SERVICE_GROUP venv/
fi

# Pull latest changes (if using git)
if [ -d ".git" ]; then
    echo "📥 Pulling latest changes..."
    git pull origin main
fi

# Install dependencies
echo "📦 Installing dependencies..."
sudo -u $SERVICE_USER bash -c "cd $APP_DIR && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

# Set proper permissions
echo "🔐 Setting permissions..."
chown -R $SERVICE_USER:$SERVICE_GROUP $APP_DIR/data/ 2>/dev/null || true
chmod -R 755 $APP_DIR/data/ 2>/dev/null || true
chown $SERVICE_USER:$SERVICE_GROUP $APP_DIR/main.py
chown -R $SERVICE_USER:$SERVICE_GROUP $APP_DIR/venv/

# Provision environment file if template exists
if [ -f "production.env" ] && [ ! -f "/etc/fastapi-fileserver.env" ]; then
    echo "⚙️ Creating environment file..."
    cp production.env /etc/fastapi-fileserver.env
    echo "⚠️ WARNING: Please edit /etc/fastapi-fileserver.env and set your SESSION_SECRET!"
fi

# Install and enable systemd service
if [ -f "fastapi-fileserver.service" ]; then
    echo "⚙️ Installing systemd service..."
    cp fastapi-fileserver.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable $APP_NAME
fi

# Install and enable nginx configuration
if [ -f "nginx-site.conf" ]; then
    echo "🌐 Installing nginx configuration..."
    cp nginx-site.conf /etc/nginx/sites-available/fastapi-fileserver
    
    # Enable the site
    ln -sf /etc/nginx/sites-available/fastapi-fileserver /etc/nginx/sites-enabled/
    
    # Test and reload nginx
    nginx -t && systemctl reload nginx
fi

# Start/restart the service
echo "🔄 Starting FastAPI service..."
systemctl restart $APP_NAME

# Check service status
echo "📊 Service status:"
systemctl status $APP_NAME --no-pager -l

echo "✅ Deployment completed successfully!"
echo "🌐 Your API should be running at your domain/IP address"
echo "📋 Check logs with: journalctl -u $APP_NAME -f"
echo "⚠️ Don't forget to:"
echo "   - Edit /etc/fastapi-fileserver.env with your real SESSION_SECRET"
echo "   - Update server_name in nginx config with your domain"
echo "   - Configure SSL/TLS with certbot for production use"