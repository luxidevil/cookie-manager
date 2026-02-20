#!/bin/bash

# ==============================================
# Copy Cookie Manager files to GCP VM
# Run from the directory containing your app files
# ==============================================

set -e

echo "╔═══════════════════════════════════════════════════════╗"
echo "║       📦 Copy Files to GCP VM                         ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Get VM IP
if [ -z "$1" ]; then
    echo "Usage: ./copy-to-vm.sh <VM_EXTERNAL_IP> [username]"
    echo ""
    echo "Example:"
    echo "  ./copy-to-vm.sh 35.123.45.67"
    echo "  ./copy-to-vm.sh 35.123.45.67 myuser"
    echo ""
    echo "Find your VM's External IP at:"
    echo "https://console.cloud.google.com/compute/instances"
    exit 1
fi

VM_IP=$1
USER=${2:-$(whoami)}
REMOTE_DIR="/opt/cookie-manager"

echo "Copying to: $USER@$VM_IP:$REMOTE_DIR"
echo ""

# Check required files exist
REQUIRED_FILES=("Dockerfile" "nginx.conf" "supervisord.conf" "backend" "frontend")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -e "$file" ]; then
        echo "❌ Error: Required file/folder '$file' not found!"
        echo "Make sure you're running this from the app directory."
        exit 1
    fi
done
echo "✓ All required files found"

# Create archive
echo ""
echo "Creating archive..."
TMP_FILE=$(mktemp /tmp/cookie-manager-XXXXXX.tar.gz)
tar -czf $TMP_FILE \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='.env' \
    --exclude='build' \
    --exclude='*.log' \
    Dockerfile nginx.conf supervisord.conf backend frontend
echo "✓ Archive created"

# Copy to VM
echo ""
echo "Uploading to VM... (this may take a minute)"
scp $TMP_FILE $USER@$VM_IP:/tmp/cookie-manager.tar.gz
echo "✓ Upload complete"

# Extract on VM
echo ""
echo "Extracting on VM..."
ssh $USER@$VM_IP << 'REMOTESCRIPT'
set -e
sudo mkdir -p /opt/cookie-manager
cd /opt/cookie-manager
sudo tar -xzf /tmp/cookie-manager.tar.gz
rm /tmp/cookie-manager.tar.gz
echo "Files extracted to /opt/cookie-manager"
REMOTESCRIPT

# Cleanup
rm $TMP_FILE

echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║         ✅ Files Copied Successfully!                 ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "Next steps - SSH to your VM and run:"
echo ""
echo "  ssh $USER@$VM_IP"
echo "  cd /opt/cookie-manager"
echo "  sudo docker compose -f docker-compose.prod.yml up -d --build"
echo ""
echo "Then access: http://$VM_IP"
echo ""
