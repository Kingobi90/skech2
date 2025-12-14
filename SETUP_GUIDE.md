# Skechers Inventory System - Complete Setup Guide

## Overview

This system now includes **two server options**:

1. **Flask Server (Port 5001)**: Original backend with basic functionality
2. **FastAPI Server (Port 8000)**: Enhanced server with features from the working old app

## What's New - Enhanced FastAPI Server

Based on the working `chukwushoescanner-main` app, the new FastAPI server includes:

✅ **Smart Excel Parsing**: Automatic column detection (no hardcoded positions)  
✅ **Image Extraction**: Extracts embedded images from Excel files  
✅ **XLSB Support**: Parse binary Excel files  
✅ **Keyboard Typing**: Automated keyboard input with OCR validation  
✅ **WebSocket Sync**: Real-time multi-device synchronization  
✅ **Better Performance**: Async/await for faster processing  

## Quick Start

### 1. Backend Setup

```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Start the enhanced FastAPI server
./start_server.sh
```

The server will display:
```
✅ Server starting on:
   Local:   http://127.0.0.1:8000
   Network: http://YOUR_LOCAL_IP:8000

📱 Configure this URL in your iOS app
```

### 2. iOS App Configuration

Open `ios/SkechersInventory/Managers/APIManager.swift` and update the base URL:

```swift
// Line 16 - Update with your Mac's IP address
baseURL = "http://YOUR_LOCAL_IP:8000"
```

To find your Mac's IP:
```bash
ipconfig getifaddr en0
```

### 3. Build and Run iOS App

```bash
cd ios
open SkechersInventory.xcodeproj
```

In Xcode:
1. Select your device/simulator
2. Press ⌘R to build and run

## Server Comparison

### When to Use FastAPI Server (Port 8000)

Use the FastAPI server if you need:
- ✅ Image extraction from Excel files
- ✅ Keyboard typing automation
- ✅ OCR validation
- ✅ WebSocket real-time sync
- ✅ XLSB file support
- ✅ Better performance for large files

### When to Use Flask Server (Port 5001)

Use the Flask server if you need:
- Basic Excel parsing only
- Simpler deployment
- Existing integrations

## Features by Server

| Feature | Flask (5001) | FastAPI (8000) |
|---------|--------------|----------------|
| Excel Parsing | ✅ | ✅ Enhanced |
| Image Extraction | ❌ | ✅ |
| XLSB Support | ❌ | ✅ |
| Keyboard Typing | ❌ | ✅ |
| OCR Validation | ❌ | ✅ |
| WebSocket Sync | ❌ | ✅ |
| Database Storage | ✅ | ✅ |
| File Management | ✅ | ✅ |

## API Endpoints

### FastAPI Server (Port 8000)

**Health Check:**
```
GET /
GET /api/status
```

**Excel Parsing:**
```
POST /api/parse/ki          # Key Initiative files
POST /api/parse/allbought   # All Bought files
```

**Lookup & Typing:**
```
GET /api/lookup?code=123456      # Type code with OCR validation
GET /api/type-only?code=123456   # Type code without validation
```

**WebSocket:**
```
WS /ws/{device_id}/{user_name}
```

**Activity:**
```
POST /api/activity/log
GET /api/activity/recent?limit=50
GET /api/devices/connected
```

### Flask Server (Port 5001)

**File Upload:**
```
POST /api/files/upload
```

**Lookup:**
```
GET /api/lookup?style=123456&color=BBK
```

**Warehouse:**
```
POST /api/warehouse/classify
GET /api/warehouse/pending
POST /api/warehouse/approve
```

## Excel File Format

The system automatically detects columns by analyzing data patterns:

### Required Columns

**Style Number:**
- Format: 6 digits (e.g., 123456)
- Detection: Looks for 6-digit numbers in any column

**Color:**
- Format: 3-4 letter codes (e.g., BBK, WSL, WTRG)
- Detection: Looks for "Color" header or 3-4 letter patterns

### Optional Columns

- **Division**: Product category
- **Outsole**: Sole type
- **Color Description**: Full color name
- **Image**: Embedded product images (XLSX only)

### Example Excel Structure

| Image | Style | Color | Division | Outsole |
|-------|-------|-------|----------|---------|
| [img] | 123456 | BBK | MENS | RUBBER |
| [img] | 234567 | WSL | WOMENS | EVA |

**Note:** Column order doesn't matter - the system detects them automatically!

## Image Extraction

### How It Works

1. Upload XLSX file with embedded images
2. Server extracts images from cells
3. Images saved as: `{style}_{color}.png`
4. URLs returned in response: `/uploads/shoe_images/123456_BBK.png`

### Requirements

- File format: XLSX (not XLSB)
- Images must be embedded (not linked)
- Recommended size: < 2MB per image

### Accessing Images

Images are served at:
```
http://YOUR_SERVER:8000/uploads/shoe_images/{style}_{color}.png
```

## Keyboard Typing Feature

### Setup

1. Grant accessibility permissions to Terminal/Python:
   - System Preferences → Security & Privacy → Privacy → Accessibility
   - Add Terminal.app or Python

2. Open target application (e.g., web browser with form)

3. Place cursor in the style code field

4. Scan barcode or manually trigger lookup

### How It Works

1. Server receives style code
2. Types code into focused field
3. Presses Tab to move to next field
4. Waits 1.5 seconds for validation
5. Captures screenshot of validation area
6. Uses OCR to read validation message
7. Returns whether style was found

### OCR Configuration

Adjust screenshot region in `fastapi_server.py`:

```python
SCREENSHOT_REGION = {
    "left": 400,    # X position
    "top": 50,      # Y position
    "width": 800,   # Width
    "height": 200   # Height
}
```

## WebSocket Real-Time Sync

### Connecting

```swift
let url = URL(string: "ws://YOUR_SERVER:8000/ws/\(deviceId)/\(userName)")!
let webSocket = URLSessionWebSocketTask(...)
```

### Message Types

**Session Summary:**
```json
{
  "type": "session_summary",
  "summary": "Processed 50 items"
}
```

**Inventory Update:**
```json
{
  "type": "inventory_update",
  "action": "file_uploaded"
}
```

## Database

Both servers use the same PostgreSQL database:

```bash
# Create database
createdb skechers_inventory

# Run migrations (if using Flask)
cd backend
python -c "from app.core.database import init_db; init_db()"
```

## Troubleshooting

### Server Won't Start

**Port already in use:**
```bash
# Kill process on port 8000
kill -9 $(lsof -ti:8000)

# Or use different port
uvicorn fastapi_server:app --port 8001
```

**Missing dependencies:**
```bash
pip install -r requirements.txt --upgrade
```

### iOS App Can't Connect

**Check server is running:**
```bash
curl http://YOUR_LOCAL_IP:8000/
```

**Verify IP address:**
```bash
ipconfig getifaddr en0
```

**Check firewall:**
- System Preferences → Security & Privacy → Firewall
- Allow Python/Terminal

### Image Extraction Not Working

**Install image loader:**
```bash
pip install openpyxl-image-loader
```

**Check file format:**
- Must be XLSX (not XLSB)
- Images must be embedded

**Verify directory:**
```bash
ls -la backend/uploads/shoe_images/
```

### Keyboard Typing Not Working

**Grant permissions:**
1. System Preferences → Security & Privacy
2. Privacy → Accessibility
3. Add Terminal.app or Python

**Test manually:**
```bash
curl "http://localhost:8000/api/type-only?code=test"
```

### OCR Not Detecting

**Install Tesseract:**
```bash
brew install tesseract
```

**Test OCR:**
```python
import pytesseract
from PIL import Image
print(pytesseract.image_to_string(Image.open('test.png')))
```

## Performance Tips

### Large Excel Files

- Use XLSB format (faster parsing)
- Split files > 10,000 rows
- Upload during off-peak hours

### Image Optimization

- Compress images before embedding
- Use PNG or JPEG format
- Recommended size: 800x600 or smaller

### Database

- Regular VACUUM on PostgreSQL
- Index on style_number and color columns
- Archive old data periodically

## Development

### Running Both Servers

**Terminal 1 - Flask:**
```bash
cd backend
python app.py
```

**Terminal 2 - FastAPI:**
```bash
cd backend
python fastapi_server.py
```

### Testing

```bash
# Test FastAPI server
curl http://localhost:8000/

# Upload test file
curl -X POST http://localhost:8000/api/parse/ki \
  -F "file=@testfile.xlsx" \
  -F "user_id=test"

# Test keyboard typing
curl "http://localhost:8000/api/lookup?code=123456"
```

### Switching Servers in iOS

Edit `APIManager.swift`:

```swift
// FastAPI (enhanced features)
baseURL = "http://10.0.0.60:8000"

// Flask (basic features)
baseURL = "http://10.0.0.60:5001"
```

## Production Deployment

### FastAPI Server

```bash
# Install production server
pip install gunicorn uvicorn[standard]

# Run with Gunicorn
gunicorn fastapi_server:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

### Environment Variables

Create `.env` file:

```env
DATABASE_URL=postgresql://user:pass@localhost/skechers_inventory
SECRET_KEY=your-secret-key-here
DEBUG=False
MAX_CONTENT_LENGTH=52428800
AUTO_DROP_ENABLED=True
```

### Nginx Reverse Proxy

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /ws {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## Support

For issues or questions:
1. Check logs: `backend/logs/`
2. Review troubleshooting section
3. Test with curl commands
4. Verify iOS app configuration

## Next Steps

1. ✅ Start FastAPI server
2. ✅ Configure iOS app with server IP
3. ✅ Test file upload
4. ✅ Test image extraction
5. ✅ Try keyboard typing (optional)
6. ✅ Enable WebSocket sync (optional)

Enjoy the enhanced Skechers Inventory System! 🚀
