# Cookie Manager - GCP VM Deployment Guide

This guide will help you deploy the Cookie Manager application on a **GCP Compute Engine VM** for 24/7 operation.

## Overview

- **VM Type**: e2-medium (2 vCPU, 4GB RAM) - ~$25/month
- **OS**: Ubuntu 22.04 LTS
- **Stack**: Docker + Docker Compose
- **Components**: MongoDB + FastAPI Backend + React Frontend (all on one VM)

---

## Step 1: Create GCP VM

### Option A: Using GCP Console (Web UI)

1. Go to [GCP Console](https://console.cloud.google.com/compute/instances)
2. Click **"Create Instance"**
3. Configure:
   - **Name**: `cookie-manager-vm`
   - **Region**: Choose closest to your users
   - **Machine type**: `e2-medium` (2 vCPU, 4 GB memory)
   - **Boot disk**: Click "Change"
     - OS: **Ubuntu**
     - Version: **Ubuntu 22.04 LTS**
     - Size: **20 GB** (or more if needed)
   - **Firewall**: Check both:
     - ✅ Allow HTTP traffic
     - ✅ Allow HTTPS traffic
4. Click **"Create"**

### Option B: Using gcloud CLI

```bash
# Set your project
gcloud config set project YOUR_PROJECT_ID

# Create the VM
gcloud compute instances create cookie-manager-vm \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=20GB \
  --tags=http-server,https-server

# Create firewall rule for HTTP (if not exists)
gcloud compute firewall-rules create allow-http \
  --allow tcp:80 \
  --target-tags=http-server \
  --description="Allow HTTP traffic"
```

---

## Step 2: Connect to VM

### Using GCP Console
1. Go to [VM Instances](https://console.cloud.google.com/compute/instances)
2. Click **"SSH"** button next to your VM

### Using gcloud CLI
```bash
gcloud compute ssh cookie-manager-vm --zone=us-central1-a
```

### Using standard SSH
```bash
ssh -i ~/.ssh/your-key username@VM_EXTERNAL_IP
```

---

## Step 3: Run Setup Script on VM

Once connected to the VM:

```bash
# Download setup script (or copy manually)
wget -O vm-setup.sh https://raw.githubusercontent.com/YOUR_REPO/vm-setup.sh
# OR copy the vm-setup.sh content manually

# Make executable and run
chmod +x vm-setup.sh
sudo ./vm-setup.sh
```

### What the setup script does:
1. Updates system packages
2. Installs Docker and Docker Compose
3. Creates `/opt/cookie-manager` directory
4. Creates systemd service for auto-start
5. Creates `.env` configuration file

---

## Step 4: Deploy Application Files

### Option A: From Local Machine (Recommended)

From your local machine where you have the code:

```bash
# Make the deploy script executable
chmod +x deploy-to-vm.sh

# Deploy (replace with your VM's external IP)
./deploy-to-vm.sh YOUR_VM_IP your-ssh-username
```

### Option B: Manual Copy via SCP

```bash
# From your local machine
scp -r Dockerfile docker-compose.prod.yml nginx.conf supervisord.conf backend frontend username@VM_IP:/tmp/

# On the VM
sudo mv /tmp/{Dockerfile,docker-compose.prod.yml,nginx.conf,supervisord.conf,backend,frontend} /opt/cookie-manager/
```

### Option C: Clone from Git Repository

On the VM:
```bash
cd /opt/cookie-manager
sudo git clone YOUR_REPO_URL .
```

---

## Step 5: Configure Environment

On the VM, edit the environment file:

```bash
sudo nano /opt/cookie-manager/.env
```

Change the `JWT_SECRET` to a strong random string:

```env
JWT_SECRET=your-super-secret-random-string-change-this
RDP_ENDPOINT_URL=
```

---

## Step 6: Start the Application

```bash
# Start the service
sudo systemctl start cookie-manager

# Check status
sudo systemctl status cookie-manager

# View logs
cd /opt/cookie-manager
sudo docker compose -f docker-compose.prod.yml logs -f
```

---

## Step 7: Access Your Application

Open your browser and go to:

```
http://YOUR_VM_EXTERNAL_IP
```

**Default Login:**
- Username: `seko`
- Password: `SEKO1234`

---

## Management Commands

### Service Control
```bash
# Start
sudo systemctl start cookie-manager

# Stop
sudo systemctl stop cookie-manager

# Restart
sudo systemctl restart cookie-manager

# Check status
sudo systemctl status cookie-manager

# View service logs
journalctl -u cookie-manager -f
```

### Docker Commands
```bash
cd /opt/cookie-manager

# View logs
sudo docker compose -f docker-compose.prod.yml logs -f

# View specific service logs
sudo docker compose -f docker-compose.prod.yml logs -f app
sudo docker compose -f docker-compose.prod.yml logs -f mongo

# Restart containers
sudo docker compose -f docker-compose.prod.yml restart

# Rebuild and restart
sudo docker compose -f docker-compose.prod.yml up -d --build

# Stop all
sudo docker compose -f docker-compose.prod.yml down

# Stop and remove volumes (⚠️ DELETES DATA)
sudo docker compose -f docker-compose.prod.yml down -v
```

### Database Backup
```bash
# Backup MongoDB
sudo docker compose -f docker-compose.prod.yml exec mongo mongodump --out /data/backup

# Copy backup from container
sudo docker cp $(sudo docker compose -f docker-compose.prod.yml ps -q mongo):/data/backup ./mongo-backup-$(date +%Y%m%d)
```

---

## Troubleshooting

### App not accessible
1. Check firewall rules allow port 80
2. Check VM external IP is correct
3. Check docker containers are running:
   ```bash
   sudo docker ps
   ```

### Containers not starting
```bash
# Check detailed logs
cd /opt/cookie-manager
sudo docker compose -f docker-compose.prod.yml logs --tail=100

# Check disk space
df -h
```

### MongoDB connection issues
```bash
# Check if mongo container is healthy
sudo docker compose -f docker-compose.prod.yml ps

# Restart mongo
sudo docker compose -f docker-compose.prod.yml restart mongo
```

### Out of memory
```bash
# Check memory usage
free -h

# Check docker stats
sudo docker stats
```

---

## Cost Estimation (24/7 operation)

| Resource | Monthly Cost |
|----------|-------------|
| e2-medium VM | ~$25 |
| 20GB Boot Disk | ~$1 |
| Network Egress | ~$1-5 (varies) |
| **Total** | **~$27-31/month** |

*Costs may vary by region. Check [GCP Pricing Calculator](https://cloud.google.com/products/calculator) for accurate estimates.*

---

## Security Recommendations

1. **Change default credentials** in the application
2. **Use a strong JWT_SECRET** in production
3. **Enable HTTPS** using Let's Encrypt (optional setup below)
4. **Restrict SSH access** to your IP only
5. **Regular backups** of MongoDB data

### Optional: Enable HTTPS with Let's Encrypt

If you have a domain name:

```bash
# Install certbot
sudo apt install certbot

# Get certificate (stop app first)
sudo systemctl stop cookie-manager
sudo certbot certonly --standalone -d yourdomain.com

# Update nginx.conf for SSL (manual step required)
```

---

## Quick Reference

| Task | Command |
|------|--------|
| Start app | `sudo systemctl start cookie-manager` |
| Stop app | `sudo systemctl stop cookie-manager` |
| View logs | `cd /opt/cookie-manager && sudo docker compose -f docker-compose.prod.yml logs -f` |
| Restart | `sudo systemctl restart cookie-manager` |
| Rebuild | `cd /opt/cookie-manager && sudo docker compose -f docker-compose.prod.yml up -d --build` |
| Check status | `sudo docker ps` |
