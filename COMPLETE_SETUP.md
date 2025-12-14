# Skechers Inventory System - Complete Setup

## ✅ All Features Implemented

The FastAPI server now includes **all features** from the old working app, tailored to your current setup:

### Core Features
- ✅ **Smart Excel Parsing** - Automatic column detection
- ✅ **Image Extraction** - Extracts embedded images from Excel
- ✅ **XLSB Support** - Binary Excel file parsing
- ✅ **OCR Validation** - Keyboard typing with OCR validation
- ✅ **WebSocket Sync** - Real-time multi-device synchronization
- ✅ **Activity Logging** - Track and broadcast user activities
- ✅ **Database Integration** - PostgreSQL with existing models

## Quick Start

```bash
cd backend
./start_server.sh
```

Server runs on: **http://YOUR_LOCAL_IP:8000**

## API Endpoints

### File Upload
```
POST /api/files/upload
```
Upload XLSX or XLSB files. Auto-detects category from filename.

### OCR Lookup
```
GET /api/lookup?code=123456
```
Types code, presses Tab, validates with OCR, broadcasts to connected devices.

**Requirements:**
- Grant accessibility permissions to Terminal/Python
- Place cursor in target field before calling
- Tesseract OCR installed: `brew install tesseract`

### Activity Logging
```
POST /api/activity/log
Body: {"action": "file_uploaded", "user": "John", "details": "..."}

GET /api/activity/recent?limit=50
```
Log activities and retrieve recent logs. All activities broadcast via WebSocket.

### WebSocket
```
WS /ws/{device_id}/{user_name}
```

**Message Types:**
- `session_summary` - Session ended notification
- `inventory_update` - Inventory changed
- `file_uploaded` - File upload notification
- `lookup_completed` - OCR lookup completed

### Connected Devices
```
GET /api/devices/connected
```
Get list of currently connected WebSocket clients.

### Health Check
```
GET /health
GET /api/health
```

## OCR Configuration

### Screenshot Region
Edit `fastapi_server.py`:

```python
SCREENSHOT_REGION = {
    "left": 400,    # X position
    "top": 50,      # Y position  
    "width": 800,   # Width
    "height": 200   # Height
}
```

### Accessibility Permissions

1. System Preferences → Security & Privacy → Privacy
2. Select "Accessibility"
3. Add Terminal.app or Python
4. Restart Terminal

### Test OCR
```bash
curl "http://localhost:8000/api/lookup?code=123456"
```

## WebSocket Integration

### iOS App Connection
```swift
let url = URL(string: "ws://YOUR_SERVER:8000/ws/\(deviceId)/\(userName)")!
let webSocket = URLSessionWebSocketTask(...)
```

### Send Messages
```json
{
  "type": "file_uploaded",
  "filename": "test.xlsx"
}
```

### Receive Broadcasts
```json
{
  "type": "notification",
  "title": "File Uploaded",
  "body": "John uploaded test.xlsx"
}
```

## Activity Logging

### Log Activity
```bash
curl -X POST http://localhost:8000/api/activity/log \
  -H "Content-Type: application/json" \
  -d '{"action": "scan_completed", "user": "John", "items": 50}'
```

### Get Recent Activities
```bash
curl http://localhost:8000/api/activity/recent?limit=20
```

## Excel Parsing

### Smart Column Detection
Automatically detects:
- **Style**: 6-digit numbers
- **Color**: 3-4 letter codes (BBK, WSL, etc.)
- **Division, Outsole**: By header name

### Image Extraction
- XLSX files only (not XLSB)
- Images saved as `{style}_{color}.png`
- Accessible at `/uploads/shoe_images/{filename}`

### XLSB Support
- Faster parsing for large files
- No image extraction (format limitation)
- Same column detection

## Complete Feature List

| Feature | Endpoint | Status |
|---------|----------|--------|
| Excel Upload | POST /api/files/upload | ✅ |
| Image Extraction | (automatic) | ✅ |
| XLSB Parsing | (automatic) | ✅ |
| OCR Lookup | GET /api/lookup | ✅ |
| Activity Log | POST /api/activity/log | ✅ |
| Recent Activities | GET /api/activity/recent | ✅ |
| WebSocket Sync | WS /ws/{id}/{name} | ✅ |
| Connected Devices | GET /api/devices/connected | ✅ |
| Health Check | GET /health | ✅ |
| Database Health | GET /api/health | ✅ |

## Architecture

```
FastAPI Server (Port 8000)
├── Excel Parsing (openpyxl + pyxlsb)
├── Image Extraction (openpyxl-image-loader)
├── OCR Validation (pytesseract + pynput)
├── WebSocket Manager (real-time sync)
├── Activity Logger (in-memory + broadcast)
└── Database Integration (SQLAlchemy + PostgreSQL)

iOS App
├── APIManager (port 8000)
├── WebSocket Client (optional)
└── File Upload UI
```

## Testing

### Test Server
```bash
curl http://localhost:8000/
```

### Test File Upload
```bash
curl -X POST http://localhost:8000/api/files/upload \
  -F "file=@test.xlsx"
```

### Test OCR (requires accessibility permissions)
```bash
curl "http://localhost:8000/api/lookup?code=123456"
```

### Test WebSocket
```bash
# Use wscat or similar WebSocket client
wscat -c ws://localhost:8000/ws/test-device/TestUser
```

### Test Activity Logging
```bash
curl -X POST http://localhost:8000/api/activity/log \
  -H "Content-Type: application/json" \
  -d '{"action": "test", "user": "Test"}'

curl http://localhost:8000/api/activity/recent
```

## Troubleshooting

### OCR Not Working
```bash
# Install Tesseract
brew install tesseract

# Grant accessibility permissions
# System Preferences → Security & Privacy → Accessibility

# Test manually
python3 -c "import pytesseract; print(pytesseract.get_tesseract_version())"
```

### WebSocket Connection Failed
- Check firewall settings
- Verify server is running on 0.0.0.0 (not 127.0.0.1)
- Test with: `wscat -c ws://YOUR_IP:8000/ws/test/test`

### Images Not Extracting
- Ensure file is XLSX (not XLSB)
- Images must be embedded (not linked)
- Check `backend/uploads/shoe_images/` exists

### Keyboard Typing Not Working
- Grant accessibility permissions
- Place cursor in target field
- Test with simple text field first

## iOS App Configuration

Already configured in `APIManager.swift`:
```swift
baseURL = "http://10.0.0.60:8000"
```

Update IP address to match your Mac's IP:
```bash
ipconfig getifaddr en0
```

## Production Deployment

### Environment Variables
```env
DATABASE_URL=postgresql://user:pass@localhost/skechers_inventory
SECRET_KEY=your-secret-key
DEBUG=False
```

### Run with Gunicorn
```bash
gunicorn fastapi_server:app \
  -w 4 \
  -k uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8000
```

### Nginx Configuration
```nginx
location /ws {
    proxy_pass http://127.0.0.1:8000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

## Summary

**Status**: ✅ **READY FOR USE**

All features from the old working app are now integrated:
- Smart Excel parsing with image extraction
- OCR validation with keyboard typing
- WebSocket real-time synchronization
- Activity logging and broadcasting
- Compatible with existing iOS app endpoints
- Database integration with PostgreSQL

Everything is tailored to work with your current setup and existing database models.
