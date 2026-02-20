#!/bin/bash

# ==============================================
# Cookie Manager - GCP VM Setup Script
# Run this script on a fresh GCP VM (Ubuntu 22.04/24.04)
# ==============================================

set -e

echo "==========================================="
echo "  Cookie Manager - VM Setup Script"
echo "==========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (use sudo)"
    exit 1
fi

# Step 1: Update system
echo ""
echo "Step 1: Updating system packages..."
apt-get update && apt-get upgrade -y
print_status "System updated"

# Step 2: Install Docker
echo ""
echo "Step 2: Installing Docker..."
if ! command -v docker &> /dev/null; then
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    print_status "Docker installed"
else
    print_status "Docker already installed"
fi

# Step 3: Enable Docker service
echo ""
echo "Step 3: Enabling Docker service..."
systemctl enable docker
systemctl start docker
print_status "Docker service enabled"

# Step 4: Create app directory
echo ""
echo "Step 4: Setting up application directory..."
APP_DIR="/opt/cookie-manager"
mkdir -p $APP_DIR
print_status "App directory created at $APP_DIR"

# Step 5: Create environment file
echo ""
echo "Step 5: Creating environment configuration..."
if [ ! -f "$APP_DIR/.env" ]; then
    cat > $APP_DIR/.env << 'EOF'
# Cookie Manager Environment Configuration
# Edit these values as needed

# JWT Secret - CHANGE THIS IN PRODUCTION!
JWT_SECRET=seko-cookie-secret-key-2024-change-me

# RDP Endpoint (optional - leave empty if not used)
RDP_ENDPOINT_URL=
EOF
    print_status "Environment file created at $APP_DIR/.env"
    print_warning "Please edit $APP_DIR/.env and change JWT_SECRET!"
else
    print_status "Environment file already exists"
fi

# Step 6: Create systemd service
echo ""
echo "Step 6: Creating systemd service for auto-start..."
cat > /etc/systemd/system/cookie-manager.service << EOF
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
EOF

systemctl daemon-reload
systemctl enable cookie-manager.service
print_status "Systemd service created and enabled"

echo ""
echo "==========================================="
echo "  Setup Complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "  1. Copy your application files to: $APP_DIR"
echo "  2. Edit the .env file: nano $APP_DIR/.env"
echo "  3. Start the application: systemctl start cookie-manager"
echo "  4. Check status: systemctl status cookie-manager"
echo "  5. View logs: docker compose -f $APP_DIR/docker-compose.prod.yml logs -f"
echo ""
echo "The app will be available at: http://YOUR_VM_IP"
echo "Default login: seko / SEKO1234"
echo ""
