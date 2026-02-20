# 🍪 Cookie Manager - SUPER EASY GCP VM Setup

## ⏱️ Total Time: ~15 minutes

---

## 📋 What You'll Get

A cookie management app running 24/7 on Google Cloud:
- **Cost**: ~$25-30/month (or FREE with $300 GCP credits!)
- **Runs**: 24/7 automatically
- **Includes**: MongoDB database, backend API, frontend UI

---

## 🚀 STEP-BY-STEP GUIDE

### Step 1: Get Google Cloud Account (2 min)

1. Go to **[cloud.google.com](https://cloud.google.com)**
2. Click **"Get Started Free"**
3. Sign in with your Google account
4. Add payment method (you won't be charged - you get $300 free credits!)

---

### Step 2: Create a Virtual Machine (3 min)

1. **Go to**: [console.cloud.google.com/compute](https://console.cloud.google.com/compute/instances)

2. **Click**: The blue **"CREATE INSTANCE"** button at the top

3. **Fill in these settings**:

   | Setting | What to Enter |
   |---------|---------------|
   | **Name** | `cookie-manager` |
   | **Region** | Pick any (closest to you is best) |
   | **Machine type** | Select `e2-medium` |

4. **Change the disk**:
   - Click **"CHANGE"** in Boot disk section
   - Select **Ubuntu** as Operating System
   - Select **Ubuntu 22.04 LTS** as Version
   - Change Size to **30 GB**
   - Click **"SELECT"**

5. **Enable web traffic**:
   - ✅ Check **"Allow HTTP traffic"**
   - ✅ Check **"Allow HTTPS traffic"**

6. **Click**: The blue **"CREATE"** button at the bottom

7. **Wait** 1-2 minutes for the green checkmark ✓

---

### Step 3: Connect to Your VM (1 min)

1. After VM is created, you'll see it in the list
2. Find the **"SSH"** button in the "Connect" column
3. Click **"SSH"** - a black terminal window will open

![SSH Button Location](https://storage.googleapis.com/gcp-community/tutorials/ssh-button.png)

---

### Step 4: Download & Install the App (5-10 min)

**Copy and paste these commands ONE BY ONE into the black terminal:**

```bash
# Command 1: Go to temp folder
cd /tmp
```

```bash
# Command 2: Download the app (Replace URL with your actual download link)
# If you have the tarball file, upload it to the VM first
# OR use scp from your local machine:
# scp cookie-manager-deploy.tar.gz YOUR_USERNAME@YOUR_VM_IP:/tmp/
```

```bash
# Command 3: Create app directory
sudo mkdir -p /opt/cookie-manager
```

```bash
# Command 4: Extract files (if you uploaded the tarball)
sudo tar -xzf /tmp/cookie-manager-deploy.tar.gz -C /opt/cookie-manager
```

```bash
# Command 5: Run the setup script
cd /opt/cookie-manager
sudo bash ONE-CLICK-SETUP.sh
```

**Wait for it to finish** (takes 3-5 minutes) ☕

---

### Step 5: Access Your App! 🎉

1. Go back to [VM Instances](https://console.cloud.google.com/compute/instances)
2. Find the **"External IP"** column (looks like `35.123.45.67`)
3. **Copy that IP address**
4. Open a new browser tab
5. Type: `http://` + your IP (example: `http://35.123.45.67`)

**Login with:**
- 👤 Username: `seko`
- 🔑 Password: `SEKO1234`

---

## ✅ You're Done!

Your app is now:
- ✅ Running 24/7
- ✅ Auto-restarts if it crashes
- ✅ Auto-starts when VM reboots
- ✅ Has its own database

---

## 📖 Common Questions

### How do I check if it's running?

SSH into your VM and run:
```bash
sudo docker ps
```
You should see 2 containers (app and mongo).

### How do I restart the app?

```bash
sudo systemctl restart cookie-manager
```

### How do I see error logs?

```bash
cd /opt/cookie-manager
sudo docker compose -f docker-compose.prod.yml logs -f
```
Press `Ctrl+C` to exit logs.

### How do I update the app?

1. Upload new tarball
2. Run:
```bash
cd /opt/cookie-manager
sudo tar -xzf /path/to/new-tarball.tar.gz
sudo docker compose -f docker-compose.prod.yml up -d --build
```

### My app won't load?

1. Check your VM has **External IP** assigned
2. Check firewall allows HTTP (port 80)
3. Wait 2-3 minutes after startup
4. Try: `sudo docker compose -f /opt/cookie-manager/docker-compose.prod.yml logs`

---

## 💰 Cost

| What | Cost |
|------|------|
| e2-medium VM (24/7) | ~$25/month |
| 30GB disk | ~$1.50/month |
| Network | ~$1-5/month |
| **Total** | **~$27-32/month** |

**With $300 free credits = ~10 months FREE!**

---

## 🆘 Need Help?

1. Check the logs (see above)
2. Make sure firewall allows HTTP traffic
3. Try restarting: `sudo systemctl restart cookie-manager`
4. Wait 5 minutes and try again

---

## 📁 Files Reference

| File | Purpose |
|------|---------|
| `ONE-CLICK-SETUP.sh` | Main setup script |
| `docker-compose.prod.yml` | App configuration |
| `DEPLOY-README.md` | Quick guide |
| `VM-DEPLOYMENT-GUIDE.md` | Detailed guide |
