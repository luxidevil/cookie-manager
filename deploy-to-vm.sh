#!/bin/bash

# ==============================================
# Deploy Cookie Manager to GCP VM
# Run this from your LOCAL machine (not the VM)
# ==============================================

set -e

echo "==========================================="
echo "  Cookie Manager - Deploy to VM"
echo "==========================================="
echo ""

# Check for required argument
if [ -z "$1" ]; then
    echo "Usage: ./deploy-to-vm.sh <VM_IP_OR_HOSTNAME> [SSH_USER]"
    echo "Example: ./deploy-to-vm.sh 35.123.45.67 your-username"
    echo ""
    echo "Make sure you have SSH access to the VM!"
    exit 1
fi

VM_HOST=$1
SSH_USER=${2:-$(whoami)}
APP_DIR="/opt/cookie-manager"

echo "Deploying to: $SSH_USER@$VM_HOST"
echo "Target directory: $APP_DIR"
echo ""

# Files to deploy
FILES_TO_COPY=(
    "Dockerfile"
    "docker-compose.prod.yml"
    "nginx.conf"
    "supervisord.conf"
    "backend"
    "frontend"
)

# Create temporary archive
echo "Creating deployment archive..."
TEMP_ARCHIVE=$(mktemp /tmp/cookie-manager-XXXXXX.tar.gz)
tar -czf $TEMP_ARCHIVE --exclude='node_modules' --exclude='.git' --exclude='__pycache__' --exclude='.env' --exclude='*.pyc' --exclude='build' ${FILES_TO_COPY[@]}
echo "Archive created: $TEMP_ARCHIVE"

# Copy to VM
echo ""
echo "Copying files to VM..."
scp $TEMP_ARCHIVE $SSH_USER@$VM_HOST:/tmp/cookie-manager.tar.gz

# Extract and setup on VM
echo ""
echo "Extracting and setting up on VM..."
ssh $SSH_USER@$VM_HOST << 'ENDSSH'
set -e
sudo mkdir -p /opt/cookie-manager
sudo tar -xzf /tmp/cookie-manager.tar.gz -C /opt/cookie-manager
sudo chown -R root:root /opt/cookie-manager
rm /tmp/cookie-manager.tar.gz
echo "Files extracted successfully"
ENDSSH

# Cleanup local temp file
rm $TEMP_ARCHIVE

echo ""
echo "==========================================="
echo "  Deployment Complete!"
echo "==========================================="
echo ""
echo "Now SSH into your VM and run:"
echo "  ssh $SSH_USER@$VM_HOST"
echo "  sudo systemctl restart cookie-manager"
echo ""
echo "Or to rebuild:"
echo "  cd /opt/cookie-manager && sudo docker compose -f docker-compose.prod.yml up -d --build"
echo ""
