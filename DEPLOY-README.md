# 🍪 Cookie Manager - Simple GCP VM Deployment

## What is this?
A cookie management application that runs on a Google Cloud VM 24/7.

**Cost: ~$25-30/month** (using e2-medium VM)

---

## 🚀 Super Easy Deployment (For Beginners)

### Prerequisites
- A Google Cloud account with billing enabled ($300 free credits for new accounts!)
- That's it!

---

## Step 1: Create a GCP Account (Skip if you have one)

1. Go to [cloud.google.com](https://cloud.google.com)
2. Click "Get Started Free"
3. Enter your details (you'll get $300 free credits!)

---

## Step 2: Create Your Virtual Machine

### Option A: Using the Web Interface (Easiest)

1. **Go to**: [GCP Console VM Instances](https://console.cloud.google.com/compute/instances)

2. **Click**: "CREATE INSTANCE" (blue button at top)

3. **Fill in these settings**:
   | Setting | Value |
   |---------|-------|
   | Name | `cookie-manager` |
   | Region | Choose nearest to you (e.g., `us-central1`) |
   | Zone | Any (e.g., `us-central1-a`) |
   | Machine type | `e2-medium` |

4. **Boot disk**: Click "CHANGE"
   - Operating system: `Ubuntu`
   - Version: `Ubuntu 22.04 LTS`
   - Size: `30 GB`
   - Click "SELECT"

5. **Firewall**: Check BOTH boxes:
   - ✅ Allow HTTP traffic
   - ✅ Allow HTTPS traffic

6. **Click**: "CREATE"

7. **Wait** 1-2 minutes for the VM to start

### Option B: Using Command Line

If you have `gcloud` CLI installed:

```bash
gcloud compute instances create cookie-manager \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=30GB \
  --tags=http-server,https-server
```

---

## Step 3: Connect to Your VM

1. Go to [VM Instances](https://console.cloud.google.com/compute/instances)
2. Find your VM named `cookie-manager`
3. Click the **"SSH"** button (opens a terminal in your browser)

![SSH Button](https://cloud.google.com/compute/images/ssh-button.png)

---

## Step 4: Install the App (Copy-Paste This!)

In the SSH terminal, copy and paste this **entire block**:

```bash
# Download and run the installer
cd /tmp
wget -q https://raw.githubusercontent.com/YOUR_REPO/main/install-cookie-manager.sh -O install.sh || curl -sO https://raw.githubusercontent.com/YOUR_REPO/main/install-cookie-manager.sh
chmod +x install.sh
sudo bash install.sh
```

**OR** if you have the files locally, copy them to VM and run:

```bash
cd /opt/cookie-manager
sudo docker compose -f docker-compose.prod.yml up -d --build
```

---

## Step 5: Access Your App! 🎉

1. Go back to [VM Instances](https://console.cloud.google.com/compute/instances)
2. Find the **External IP** of your VM (looks like `35.123.45.67`)
3. Open your browser and go to: `http://YOUR_EXTERNAL_IP`

**Login credentials:**
- Username: `seko`
- Password: `SEKO1234`

---

## 📝 Quick Reference Commands

SSH into your VM first, then use these commands:

| What you want to do | Command |
|--------------------|----------|
| Check if app is running | `sudo docker ps` |
| View app logs | `cd /opt/cookie-manager && sudo docker compose -f docker-compose.prod.yml logs -f` |
| Restart the app | `sudo systemctl restart cookie-manager` |
| Stop the app | `sudo systemctl stop cookie-manager` |
| Start the app | `sudo systemctl start cookie-manager` |
| Rebuild after code changes | `cd /opt/cookie-manager && sudo docker compose -f docker-compose.prod.yml up -d --build` |

---

## ❓ Troubleshooting

### Can't access the website?

1. **Check the External IP** is correct
2. **Check firewall**: Go to [Firewall Rules](https://console.cloud.google.com/networking/firewalls) and make sure HTTP (port 80) is allowed
3. **Check containers are running**:
   ```bash
   sudo docker ps
   ```
   You should see 2 containers running (app and mongo)

### Containers not starting?

```bash
# Check logs for errors
cd /opt/cookie-manager
sudo docker compose -f docker-compose.prod.yml logs --tail=50
```

### Out of disk space?

```bash
# Check disk usage
df -h

# Clean up Docker
sudo docker system prune -a
```

---

## 💰 Cost Breakdown

| Resource | Monthly Cost |
|----------|-------------|
| e2-medium VM (24/7) | ~$25 |
| 30GB Disk | ~$1.50 |
| Network | ~$1-5 |
| **Total** | **~$27-32/month** |

With $300 free credits, you can run this for **~10 months free!**

---

## 🔒 Security Tips

1. **Change the default password** in the app
2. **Restrict SSH access** to your IP only:
   - Go to [Firewall Rules](https://console.cloud.google.com/networking/firewalls)
   - Edit the SSH rule to only allow your IP

---

## Need Help?

If you're stuck, check the detailed guide: `VM-DEPLOYMENT-GUIDE.md`
