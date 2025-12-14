# ⚡ Quick Start Guide - Skechers Inventory System

Get up and running in under 10 minutes!

## 🎯 Prerequisites Checklist

- [ ] Python 3.9+ installed
- [ ] Xcode 15.0+ installed (for iOS)
- [ ] PostgreSQL OR SQLite
- [ ] Tesseract OCR (optional for CV features)

---

## 🚀 5-Minute Backend Setup

### 1. Open Terminal and navigate to backend folder:

```bash
cd /path/to/SkechersInventorySystem/backend
```

### 2. Create and activate virtual environment:

```bash
python3 -m venv venv
source venv/bin/activate
```

### 3. Install dependencies:

```bash
pip install -r requirements.txt
```

### 4. Create configuration file:

```bash
cat > .env << 'EOL'
DATABASE_URL=sqlite:///./skechers_inventory.db
SECRET_KEY=dev-secret-key-change-in-production
DEBUG=True
TESSERACT_PATH=
AUTO_DROP_ENABLED=True
DEFAULT_SYNC_INTERVAL_SECONDS=60
MAX_CONTENT_LENGTH=52428800
EOL
```

### 5. Start the server:

```bash
python fastapi_server.py
```

**Expected Output:**
```
✅ Database initialized successfully
✅ Tesseract configured at: /usr/local/bin/tesseract
🚀 Starting Skechers Inventory FastAPI Server
📍 Server will run at: http://192.168.1.100:8000
📱 Configure this URL in iPhone app
```

**✅ Your server IP will be displayed - note it down!**

---

## 📱 3-Minute iOS Setup

### 1. Open the project in Xcode:

```bash
cd /path/to/SkechersInventorySystem/ios/SkechersInventory
open SkechersInventory.xcodeproj
```

### 2. Build and Run:

- Select a simulator or your connected iPhone
- Press **⌘R** (or click the Play button)
- Wait for the app to build (~1-2 minutes first time)

### 3. Configure Backend Connection:

1. App opens → Tap **Settings** tab (gear icon)
2. Under "Connection" section:
   - Enter API Endpoint: `http://YOUR_SERVER_IP:8000`
     - Example: `http://192.168.1.100:8000`
     - For simulator: `http://127.0.0.1:8000`
3. Tap **"Test Connection"**
4. Wait for ✅ "Successfully connected to server"

### 4. Perform Initial Sync:

1. Tap **"Sync Now"** button
2. Wait for sync to complete
3. Return to **Home** tab

**🎉 You're ready to use the app!**

---

## 🧪 Test the App

### Test 1: Upload a Sample Catalog

1. Create a test Excel file:
   ```
   Style Number | Color | Division | Gender | Outsole
   144083       | Black | Men      | M      | Rubber
   144084       | Navy  | Women    | F      | Foam
   144085       | White | Kids     | K      | EVA
   ```

2. In the app:
   - Tap **Home** → **Upload Files**
   - Select your Excel file
   - Choose category: **Key Initiative**
   - Tap **Upload**

3. Wait for processing (~5-10 seconds)
4. Check **Home** → Total Styles should show 3

### Test 2: Camera Scanning

1. Tap **Home** → **Scan Shoe**
2. Point camera at any text with a 6-digit number
3. Tap capture button
4. View scan results

### Test 3: Coordinator Workflow

1. Tap **Home** → **Warehouse Mode** → **Coordinator**
2. Scan a shoe or enter manually
3. Classify as **Keep**, **Wait**, or **Drop**
4. Item queues for manager approval

### Test 4: Manager Approval

1. Tap **Home** → **Warehouse Mode** → **Manager**
2. Swipe right to approve ✅
3. Swipe left to reject ❌
4. View product details on cards

---

## 🔧 Troubleshooting

### Backend Won't Start

**Error: "Address already in use"**
```bash
# Kill existing process on port 8000
lsof -ti:8000 | xargs kill -9
# Then restart server
python fastapi_server.py
```

**Error: "ModuleNotFoundError"**
```bash
# Ensure virtual environment is activated
source venv/bin/activate
# Reinstall dependencies
pip install -r requirements.txt
```

### iOS App Won't Connect

**Check 1: Server Running?**
```bash
# Visit in browser
http://YOUR_SERVER_IP:8000/health
# Should return: {"status":"healthy"}
```

**Check 2: Same Network?**
- Ensure iPhone and Mac are on the same Wi-Fi network
- Disable VPN if enabled
- Check firewall isn't blocking port 8000

**Check 3: Correct URL?**
- Settings → Connection → API Endpoint
- Should be: `http://IP:8000` (no trailing slash)
- For simulator: `http://127.0.0.1:8000`
- For device: `http://YOUR_MAC_IP:8000`

### Camera Not Working

1. Settings app → Skechers Inventory → Camera → Enable
2. Restart app
3. Grant permission when prompted

---

## 📊 Quick Reference

### Common Backend Commands

```bash
# Start server
python fastapi_server.py

# Check if running
curl http://localhost:8000/health

# View logs
tail -f logs/app.log  # if logging configured

# Stop server
Ctrl+C
```

### Common iOS Development Commands

```bash
# Open in Xcode
open ios/SkechersInventory/SkechersInventory.xcodeproj

# Clean build folder (in Xcode)
Shift+⌘+K

# Build and run
⌘R

# Open iOS Simulator
xcrun simctl list devices
open -a Simulator
```

### API Quick Test (curl)

```bash
# Health check
curl http://localhost:8000/health

# Get statistics
curl http://localhost:8000/api/admin/stats

# Lookup style
curl "http://localhost:8000/api/lookup?style=144083&color=Black"
```

---

## 🎓 Learn More

- **Full Documentation**: [README.md](README.md)
- **API Reference**: [README.md#api-documentation](README.md#api-documentation)
- **Architecture**: [README.md#architecture](README.md#architecture)

---

## ✅ Success Checklist

After setup, you should have:

- [x] Backend server running on port 8000
- [x] iOS app installed on simulator/device
- [x] Backend URL configured in app Settings
- [x] Connection test passed (green dot)
- [x] Initial sync completed
- [x] Home screen shows statistics

---

## 🆘 Still Having Issues?

1. Check [Troubleshooting](README.md#troubleshooting) in main README
2. Review server logs for errors
3. Check Xcode console for iOS errors
4. Verify all prerequisites are met
5. Try restarting both server and app

---

**Happy Coding! 🎉**
