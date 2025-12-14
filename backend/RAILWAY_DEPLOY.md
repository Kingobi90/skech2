# Deploy to Railway

1. Go to https://railway.app
2. Click "Login" and sign in with GitHub
3. Click "New Project"
4. Select "Deploy from GitHub repo"
5. Authorize Railway to access your GitHub
6. Select this repository
7. Railway will auto-detect the Dockerfile and deploy
8. After deployment, you'll get a URL like: your-app.up.railway.app
9. Copy that URL - you'll need it for Cloudflare configuration

## Set Environment Variables in Railway

1. Click on your service
2. Go to "Variables" tab
3. Add these:
   - SECRET_KEY = (generate with: openssl rand -hex 32)
   - DEBUG = False
   - DATABASE_URL = sqlite:///skechers_inventory.db

## Get Your Railway URL

After deployment completes:
1. Go to "Settings" tab
2. Under "Domains", you'll see your Railway URL
3. Copy it (e.g., your-app.up.railway.app)

Then come back here and run the Cloudflare configuration!
