# Deployment Guide for Skechers Inventory System

## Deploy to Your Domain: api.obinnachukwu.org

Your iOS app is already configured to use `http://api.obinnachukwu.org` as the backend URL.

---

## Option 1: Railway (Recommended - Easiest)

### Step 1: Deploy to Railway

1. **Sign up/Login to Railway**
   - Go to https://railway.app
   - Sign in with GitHub

2. **Create New Project**
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Connect your repository or upload the `backend` folder

3. **Configure Environment Variables**
   - In Railway dashboard, go to your service
   - Click "Variables" tab
   - Add these variables:
     ```
     SECRET_KEY=your-random-secret-key-here
     DEBUG=False
     DATABASE_URL=sqlite:///skechers_inventory.db
     MAX_CONTENT_LENGTH=52428800
     UPLOAD_FOLDER=./uploads
     AUTO_DROP_ENABLED=True
     ```

4. **Get Your Railway URL**
   - After deployment, Railway will give you a URL like:
   - `https://your-app-name.up.railway.app`
   - Copy this URL (you'll need it for Cloudflare)

### Step 2: Configure Cloudflare DNS

1. **Login to Cloudflare Dashboard**
   - Go to https://dash.cloudflare.com
   - Select your domain `obinnachukwu.org`

2. **Add DNS Record**
   - Go to "DNS" tab
   - Click "Add record"
   - Type: `CNAME`
   - Name: `api`
   - Target: `your-app-name.up.railway.app` (from Railway)
   - Proxy status: **Proxied** (orange cloud)
   - TTL: Auto
   - Click "Save"

3. **Configure SSL/TLS**
   - Go to "SSL/TLS" tab
   - Set SSL/TLS encryption mode to: **Full** or **Full (strict)**

4. **Wait for DNS Propagation**
   - Usually takes 1-5 minutes
   - Test at: http://api.obinnachukwu.org/health

---

## Option 2: Render

### Step 1: Deploy to Render

1. **Sign up/Login to Render**
   - Go to https://render.com
   - Sign in with GitHub

2. **Create New Web Service**
   - Click "New +"
   - Select "Web Service"
   - Connect your GitHub repo
   - Select the `backend` folder

3. **Configure Service**
   - Name: `skechers-inventory-api`
   - Environment: `Docker`
   - Dockerfile Path: `./Dockerfile`
   - Plan: Free (or paid for better performance)

4. **Add Environment Variables**
   ```
   SECRET_KEY=your-random-secret-key-here
   DEBUG=False
   DATABASE_URL=sqlite:///skechers_inventory.db
   ```

5. **Get Your Render URL**
   - After deployment: `https://your-service.onrender.com`

### Step 2: Configure Cloudflare (same as above)
   - CNAME record pointing `api` to `your-service.onrender.com`

---

## Option 3: Fly.io

### Step 1: Install Fly CLI

```bash
# macOS
brew install flyctl

# Login
flyctl auth login
```

### Step 2: Deploy

```bash
cd backend

# Initialize fly app
flyctl launch --name skechers-inventory-api --no-deploy

# Set secrets
flyctl secrets set SECRET_KEY=$(openssl rand -hex 32)
flyctl secrets set DEBUG=False

# Deploy
flyctl deploy
```

### Step 3: Configure Cloudflare
   - CNAME record pointing `api` to `skechers-inventory-api.fly.dev`

---

## Quick Cloudflare DNS Setup Summary

Once you have your hosting URL (Railway/Render/Fly.io), configure Cloudflare:

### DNS Record
- **Type**: CNAME
- **Name**: api
- **Target**: your-hosting-url.com (without https://)
- **Proxy**: ON (orange cloud)
- **TTL**: Auto

### SSL Settings
- Go to SSL/TLS > Overview
- Set mode to: **Full** or **Full (strict)**

---

## Testing Your Deployment

1. **Test Health Endpoint**
   ```bash
   curl http://api.obinnachukwu.org/health
   ```

2. **Expected Response**
   ```json
   {
     "status": "healthy",
     "timestamp": "2025-12-14T...",
     "database_status": "healthy"
   }
   ```

3. **Test from iOS App**
   - Open the iOS app
   - Go to Settings
   - The app should automatically connect to `http://api.obinnachukwu.org`
   - Status should show "Connected"

---

## Troubleshooting

### DNS Not Resolving
- Wait 5-10 minutes for DNS propagation
- Clear DNS cache: `sudo dscacheutil -flushcache` (macOS)
- Check DNS: `nslookup api.obinnachukwu.org`

### SSL/Certificate Errors
- Ensure Cloudflare SSL mode is **Full** not **Flexible**
- Wait for Cloudflare to provision certificate (1-5 minutes)

### Connection Timeout
- Check if hosting service is running
- Verify Cloudflare proxy is enabled (orange cloud)
- Check firewall settings on hosting platform

---

## Which Option Should You Choose?

- **Railway**: Best for quick deployment, free tier, easy setup
- **Render**: Good free tier, automatic deploys from GitHub
- **Fly.io**: Best performance, requires CLI setup

**Recommendation**: Start with Railway for easiest setup.
