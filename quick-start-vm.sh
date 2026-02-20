#!/bin/bash

# ==============================================
# Cookie Manager - Quick Start for GCP VM
# Copy and paste this entire script on a fresh Ubuntu VM
# ==============================================

set -e

echo "===========================================" 
echo "  Cookie Manager - Quick Start Setup"
echo "==========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo: sudo bash quick-start-vm.sh"
    exit 1
fi

APP_DIR="/opt/cookie-manager"

# Step 1: Update and install Docker
echo ""
echo "[1/5] Installing Docker..."
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
echo "[✓] Docker installed"

# Step 2: Create directories
echo ""
echo "[2/5] Creating app directory..."
mkdir -p $APP_DIR
cd $APP_DIR
echo "[✓] Directory created: $APP_DIR"

# Step 3: Create docker-compose.prod.yml
echo ""
echo "[3/5] Creating Docker Compose configuration..."
cat > docker-compose.prod.yml << 'DOCKEREOF'
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "80:8080"
    environment:
      - MONGO_URL=mongodb://mongo:27017
      - DB_NAME=cookie_manager
      - CORS_ORIGINS=*
      - JWT_SECRET=${JWT_SECRET:-seko-cookie-secret-key-2024-production}
      - RDP_ENDPOINT_URL=${RDP_ENDPOINT_URL:-}
    depends_on:
      mongo:
        condition: service_healthy
    restart: always
    networks:
      - cookie-network

  mongo:
    image: mongo:6
    volumes:
      - mongo_data:/data/db
      - mongo_config:/data/configdb
    restart: always
    networks:
      - cookie-network
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  mongo_data:
    driver: local
  mongo_config:
    driver: local

networks:
  cookie-network:
    driver: bridge
DOCKEREOF
echo "[✓] Docker Compose file created"

# Step 4: Create environment file
echo ""
echo "[4/5] Creating environment file..."
cat > .env << 'ENVEOF'
JWT_SECRET=seko-cookie-secret-key-2024-production
RDP_ENDPOINT_URL=
ENVEOF
echo "[✓] Environment file created"

# Step 5: Create systemd service
echo ""
echo "[5/5] Creating systemd service..."
cat > /etc/systemd/system/cookie-manager.service << SERVICEEOF
[Unit]
Description=Cookie Manager Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml up -d --build
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.prod.yml up -d --build
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable cookie-manager.service
echo "[✓] Systemd service created and enabled"

echo ""
echo "==========================================="
echo "  Setup Complete!"
echo "==========================================="
echo ""
echo "IMPORTANT: You still need to copy these files to $APP_DIR:"
echo "  - Dockerfile"
echo "  - nginx.conf"
echo "  - supervisord.conf"
echo "  - backend/ (folder)"
echo "  - frontend/ (folder)"
echo ""
echo "After copying files, run:"
echo "  cd $APP_DIR"
echo "  sudo docker compose -f docker-compose.prod.yml up -d --build"
echo ""
echo "Then access: http://YOUR_VM_IP"
echo "Login: seko / SEKO1234"
echo ""
