#!/bin/bash

# ==============================================================================
# 🍪 COOKIE MANAGER - ONE COMMAND SETUP
# ==============================================================================
# 
# This script does EVERYTHING automatically:
# 1. Downloads the application
# 2. Installs Docker
# 3. Sets up auto-start
# 4. Builds and runs the app
#
# USAGE ON A FRESH GCP VM (Ubuntu 22.04):
#   curl -sSL https://YOUR_URL/setup.sh | sudo bash
#   
# OR if you have the tarball:
#   sudo bash ONE-CLICK-SETUP.sh /path/to/cookie-manager-deploy.tar.gz
#
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat << 'BANNER'
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║       🍪  COOKIE MANAGER - ONE-CLICK SETUP                           ║
║                                                                       ║
║       Installs Docker + MongoDB + App automatically!                 ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run with sudo:${NC}"
    echo "   sudo bash ONE-CLICK-SETUP.sh [tarball-path]"
    exit 1
fi

TARBALL_PATH="${1:-}"
APP_DIR="/opt/cookie-manager"

# ==============================================================================
# STEP 1: INSTALL DOCKER
# ==============================================================================
echo -e "\n${BLUE}[1/5] Installing Docker...${NC}"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}  ✓ Docker already installed${NC}"
else
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker
    echo -e "${GREEN}  ✓ Docker installed${NC}"
fi

# ==============================================================================
# STEP 2: EXTRACT APPLICATION
# ==============================================================================
echo -e "\n${BLUE}[2/5] Setting up application...${NC}"

mkdir -p $APP_DIR
cd $APP_DIR

if [ -n "$TARBALL_PATH" ] && [ -f "$TARBALL_PATH" ]; then
    echo "  Extracting from: $TARBALL_PATH"
    tar -xzf "$TARBALL_PATH" -C $APP_DIR
    echo -e "${GREEN}  ✓ Application extracted${NC}"
else
    echo -e "${YELLOW}  ⚠ No tarball provided. Checking if files exist...${NC}"
    if [ -f "$APP_DIR/Dockerfile" ]; then
        echo -e "${GREEN}  ✓ Application files found${NC}"
    else
        echo -e "${RED}  ❌ Error: No application files found!${NC}"
        echo ""
        echo "Please either:"
        echo "  1. Run with tarball: sudo bash ONE-CLICK-SETUP.sh /path/to/cookie-manager-deploy.tar.gz"
        echo "  2. Or copy files to $APP_DIR first"
        exit 1
    fi
fi

# ==============================================================================
# STEP 3: CREATE ENVIRONMENT FILE
# ==============================================================================
echo -e "\n${BLUE}[3/5] Creating environment configuration...${NC}"

if [ ! -f "$APP_DIR/.env" ]; then
    cat > $APP_DIR/.env << 'ENVEOF'
JWT_SECRET=seko-cookie-secret-key-2024-production
RDP_ENDPOINT_URL=
ENVEOF
fi
echo -e "${GREEN}  ✓ Environment file ready${NC}"

# ==============================================================================
# STEP 4: CREATE SYSTEMD SERVICE
# ==============================================================================
echo -e "\n${BLUE}[4/5] Creating auto-start service...${NC}"

cat > /etc/systemd/system/cookie-manager.service << SVCEOF
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
TimeoutStartSec=600

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable cookie-manager.service
echo -e "${GREEN}  ✓ Auto-start service created${NC}"

# ==============================================================================
# STEP 5: BUILD AND START APPLICATION
# ==============================================================================
echo -e "\n${BLUE}[5/5] Building and starting application...${NC}"
echo "  This may take 3-5 minutes on first run..."

cd $APP_DIR
docker compose -f docker-compose.prod.yml up -d --build

# Wait for health check
echo "  Waiting for services to be ready..."
sleep 10

# Check if running
if docker compose -f docker-compose.prod.yml ps | grep -q "Up"; then
    echo -e "${GREEN}  ✓ Application is running!${NC}"
else
    echo -e "${YELLOW}  ⚠ Services may still be starting. Check with: docker compose -f docker-compose.prod.yml logs${NC}"
fi

# ==============================================================================
# DONE!
# ==============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                       ║${NC}"
echo -e "${GREEN}║              ✅  INSTALLATION COMPLETE!                               ║${NC}"
echo -e "${GREEN}║                                                                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get external IP
EXTERNAL_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "YOUR_VM_IP")

echo -e "🌐 Your app is available at:"
echo -e "   ${CYAN}http://$EXTERNAL_IP${NC}"
echo ""
echo -e "🔑 Login credentials:"
echo "   Username: seko"
echo "   Password: SEKO1234"
echo ""
echo -e "📋 Useful commands:"
echo "   Check status:  sudo docker compose -f $APP_DIR/docker-compose.prod.yml ps"
echo "   View logs:     sudo docker compose -f $APP_DIR/docker-compose.prod.yml logs -f"
echo "   Restart:       sudo systemctl restart cookie-manager"
echo ""
