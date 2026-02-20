#!/bin/bash

# ==============================================
# Cookie Manager - One-Click Installer for GCP VM
# Just run: sudo bash install-cookie-manager.sh
# ==============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║       🍪 Cookie Manager - VM Installer                ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run with sudo${NC}"
    echo "Usage: sudo bash install-cookie-manager.sh"
    exit 1
fi

APP_DIR="/opt/cookie-manager"

# Function to print status
print_step() {
    echo -e "\n${BLUE}[$1/6]${NC} $2"
}

print_done() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}  ! $1${NC}"
}

# ============================================
# STEP 1: System Update
# ============================================
print_step 1 "Updating system packages..."
apt-get update -qq
apt-get upgrade -y -qq
print_done "System updated"

# ============================================
# STEP 2: Install Docker
# ============================================
print_step 2 "Installing Docker..."

if command -v docker &> /dev/null; then
    print_done "Docker already installed"
else
    # Install prerequisites
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start Docker
    systemctl enable docker
    systemctl start docker
    
    print_done "Docker installed and started"
fi

# ============================================
# STEP 3: Create App Directory
# ============================================
print_step 3 "Setting up application directory..."
mkdir -p $APP_DIR
cd $APP_DIR
print_done "Created $APP_DIR"

# ============================================
# STEP 4: Create Configuration Files
# ============================================
print_step 4 "Creating configuration files..."

# Create docker-compose.prod.yml
cat > docker-compose.prod.yml << 'COMPOSEEOF'
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
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
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
COMPOSEEOF
print_done "Created docker-compose.prod.yml"

# Create .env file
cat > .env << 'ENVEOF'
# Cookie Manager Environment Variables
# Change JWT_SECRET for better security!

JWT_SECRET=seko-cookie-secret-key-2024-production
RDP_ENDPOINT_URL=
ENVEOF
print_done "Created .env file"

# ============================================
# STEP 5: Create Systemd Service
# ============================================
print_step 5 "Creating auto-start service..."

cat > /etc/systemd/system/cookie-manager.service << SERVICEEOF
[Unit]
Description=Cookie Manager Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.prod.yml up -d --build
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable cookie-manager.service
print_done "Systemd service created and enabled"

# ============================================
# STEP 6: Summary
# ============================================
print_step 6 "Setup complete!"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ Installation Complete!                      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: You still need to copy your app files!${NC}"
echo ""
echo "Copy these files/folders to $APP_DIR:"
echo "  • Dockerfile"
echo "  • nginx.conf"
echo "  • supervisord.conf"
echo "  • backend/     (folder)"
echo "  • frontend/    (folder)"
echo ""
echo "Then start the app with:"
echo -e "  ${BLUE}cd $APP_DIR${NC}"
echo -e "  ${BLUE}sudo docker compose -f docker-compose.prod.yml up -d --build${NC}"
echo ""
echo "Your app will be at: http://YOUR_VM_EXTERNAL_IP"
echo "Login: seko / SEKO1234"
echo ""
