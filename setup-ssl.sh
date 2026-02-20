#!/bin/bash

# SSL Setup Script for flipblack-cookie.space
# Run this ONCE after your domain DNS is pointing to your VM

DOMAIN="flipblack-cookie.space"
EMAIL="admin@$DOMAIN"  # Change this to your email

echo "=== SSL Setup for $DOMAIN ==="

# Create directories
mkdir -p certbot/www certbot/conf

# Use initial nginx config (without SSL)
cp nginx-proxy/nginx-init.conf nginx-proxy/nginx.conf

# Start nginx first
sudo docker-compose up -d nginx

# Wait for nginx to start
sleep 5

# Get SSL certificate
sudo docker-compose run --rm certbot certonly \
    --webroot \
    --webroot-path /var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN \
    -d www.$DOMAIN

# Restore full nginx config with SSL
cat > nginx-proxy/nginx.conf << 'EOF'
server {
    listen 80;
    server_name flipblack-cookie.space www.flipblack-cookie.space;
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name flipblack-cookie.space www.flipblack-cookie.space;
    
    ssl_certificate /etc/letsencrypt/live/flipblack-cookie.space/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/flipblack-cookie.space/privkey.pem;
    
    location / {
        proxy_pass http://app:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Restart everything
sudo docker-compose down
sudo docker-compose up -d

echo "=== Done! ==="
echo "Your site is now live at: https://$DOMAIN"
