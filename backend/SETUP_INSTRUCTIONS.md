# Complete Setup Instructions for api.obinnachukwu.org

Your iOS app is already configured to use http://api.obinnachukwu.org!

## Part 1: Deploy Backend to Hosting Platform

Choose ONE option below:

### Option A: Railway (Easiest - Recommended)

1. Go to https://railway.app and sign in with GitHub
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your repository (or upload the backend folder)
4. Railway will auto-deploy using the Dockerfile
5. Get your Railway URL (e.g., `your-app.up.railway.app`)

### Option B: Render

1. Go to https://render.com and sign in
2. Click "New +" → "Web Service"
3. Connect GitHub and select your repo
4. Configure:
   - Environment: Docker
   - Dockerfile Path: ./Dockerfile
5. Click "Create Web Service"
6. Get your Render URL (e.g., `your-service.onrender.com`)

---

## Part 2: Get Cloudflare API Credentials

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Configure:
   - Permissions: Zone → DNS → Edit
   - Zone Resources: Include → Specific zone → obinnachukwu.org
5. Click "Continue to summary" → "Create Token"
6. **COPY THE TOKEN** (you won't see it again!)

---

## Part 3: Run Cloudflare Configuration Script

Once you have:
- ✓ Your backend deployed (Railway/Render URL)
- ✓ Your Cloudflare API token

Run these commands:

```bash
# Set your Cloudflare API token
export CF_API_TOKEN='your-api-token-here'

# Set your backend URL (from Railway/Render - WITHOUT https://)
export BACKEND_URL='your-app.up.railway.app'

# Run the configuration script
./configure_cloudflare.sh
```

**Example:**
```bash
export CF_API_TOKEN='abc123...'
export BACKEND_URL='skechers-api.up.railway.app'
./configure_cloudflare.sh
```

---

## Part 4: Test Everything

After DNS configuration (wait 1-5 minutes):

```bash
# Test health endpoint
curl http://api.obinnachukwu.org/health

# Expected response:
# {"status":"healthy","timestamp":"...","database_status":"healthy"}
```

Test from iOS app:
1. Open the Skechers Inventory app
2. Go to Settings
3. Connection status should show "Connected"
4. Try uploading a file or scanning inventory

---

## Troubleshooting

**DNS not resolving:**
```bash
# Check DNS propagation
nslookup api.obinnachukwu.org

# Flush DNS cache (macOS)
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**Still not working:**
- Check Railway/Render logs for errors
- Verify Cloudflare DNS record in dashboard
- Ensure SSL mode is "Full" in Cloudflare
- Wait up to 10 minutes for full propagation

---

## Summary

1. ✓ iOS app configured → Already done!
2. ⏳ Deploy backend → Railway/Render
3. ⏳ Get Cloudflare token → API tokens page
4. ⏳ Run `./configure_cloudflare.sh` → Configures DNS
5. ✓ Test and use!

