# 🏢 Skechers Inventory Management System

A comprehensive enterprise inventory management system with hybrid mobile-web architecture, featuring offline-first capabilities, real-time synchronization, computer vision OCR, and multi-role workflows.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Backend Setup](#backend-setup)
- [iOS App Setup](#ios-app-setup)
- [Usage Guide](#usage-guide)
- [API Documentation](#api-documentation)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## ✨ Features

### Core Capabilities
- **📱 Native iOS App** with SwiftUI and offline-first architecture
- **🖥️ FastAPI Backend** with WebSocket real-time sync
- **📊 Smart Excel Parsing** with automatic column detection
- **🤖 Computer Vision OCR** for shoe tag detection
- **🔄 Offline Queue** for seamless offline operation
- **👥 Multi-Role Workflows** (Sales Rep, Coordinator, Manager)
- **📸 Camera Scanning** with real-time detection
- **💾 Local SQLite** database with GRDB ORM
- **🌐 PostgreSQL** for server-side data
- **🔁 Incremental Sync** every 60 seconds

### Workflows
1. **Sales Rep Mode**: Quick product lookup via camera scan
2. **Coordinator Mode**: Classify incoming inventory (Keep/Wait/Drop)
3. **Manager Mode**: Swipeable card-based approval interface
4. **Placement Mode**: Assign shelf locations to approved items

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│              SKECHERS INVENTORY SYSTEM              │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────────┐      ┌──────────────────┐    │
│  │   iOS App        │◄────►│   FastAPI Server │    │
│  │  (SwiftUI)       │ HTTP │  (Python 3.x)    │    │
│  │                  │  WS  │                  │    │
│  │ • SQLite DB      │      │ • PostgreSQL     │    │
│  │ • GRDB ORM       │      │ • SQLAlchemy     │    │
│  │ • Offline Queue  │      │ • WebSockets     │    │
│  │ • Camera/OCR     │      │ • OCR/CV         │    │
│  └──────────────────┘      └──────────────────┘    │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## 📦 Prerequisites

### Backend Requirements
- **Python 3.9+**
- **PostgreSQL 14+** (or SQLite for development)
- **Tesseract OCR** (for computer vision features)
  - macOS: `brew install tesseract`
  - Ubuntu: `sudo apt-get install tesseract-ocr`
  - Windows: Download from [GitHub](https://github.com/UB-Mannheim/tesseract/wiki)

### iOS Requirements
- **Xcode 15.0+**
- **iOS 16.0+** (deployment target)
- **Swift 5.9+**
- **Mac with Apple Silicon or Intel** (for development)

---

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/SkechersInventorySystem.git
cd SkechersInventorySystem
```

### 2. Backend Setup (5 minutes)
```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Create .env file
cp .env.example .env

# Edit .env with your database credentials
nano .env

# Run the server
python fastapi_server.py
```

Server will start at `http://0.0.0.0:8000`

### 3. iOS App Setup (2 minutes)
```bash
cd ../ios/SkechersInventory

# Open in Xcode
open SkechersInventory.xcodeproj

# Update backend URL in Settings
# Run on simulator or device (⌘R)
```

---

## 🖥️ Backend Setup

### Step 1: Install Dependencies

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 2: Configure Environment

Create `.env` file:
```bash
cp .env.example .env
```

Edit `.env`:
```env
# Database (use PostgreSQL for production)
DATABASE_URL=postgresql://username:password@localhost:5432/skechers_inventory

# Or SQLite for development
# DATABASE_URL=sqlite:///./skechers_inventory.db

# Tesseract path (optional if in system PATH)
TESSERACT_PATH=/opt/homebrew/bin/tesseract

# Features
AUTO_DROP_ENABLED=True
DEFAULT_SYNC_INTERVAL_SECONDS=60
MAX_CONTENT_LENGTH=52428800
```

### Step 3: Initialize Database

The database tables are created automatically on first run. To manually initialize:

```python
from app.core.database import init_db
init_db()
```

### Step 4: Run Development Server

```bash
python fastapi_server.py
```

The server will:
- ✅ Display your local IP address
- ✅ Initialize database tables
- ✅ Configure Tesseract OCR
- ✅ Start on port 8000

### Step 5: Production Deployment (Railway)

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Add PostgreSQL plugin
railway add postgresql

# Deploy
railway up
```

---

## 📱 iOS App Setup

### Step 1: Open in Xcode

```bash
cd ios/SkechersInventory
open SkechersInventory.xcodeproj
```

### Step 2: Configure Backend URL

1. Run the app (⌘R)
2. Navigate to **Settings** tab
3. Enter your backend URL:
   - Simulator: `http://127.0.0.1:8000`
   - Physical Device: `http://YOUR_MAC_IP:8000`
   - Production: `https://your-app.railway.app`
4. Tap **Test Connection**
5. Wait for "Successfully connected" message

### Step 3: Build and Run

**For Simulator:**
- Select any iOS simulator
- Press ⌘R to build and run

**For Physical Device:**
1. Connect iPhone via USB
2. Select your device in Xcode
3. Update code signing team
4. Trust developer certificate on device
5. Press ⌘R to build and run

---

## 📖 Usage Guide

### For Sales Representatives

1. **Open App** → Home tab
2. **Tap "Scan Shoe"**
3. **Point camera** at shoe tag
4. **Tap capture** button
5. **View product info** (style, color, division)

### For Warehouse Coordinators

1. **Home** → **Warehouse Mode** → **Coordinator**
2. **Scan incoming shoes** with camera
3. **Classify each item:**
   - ✅ **Keep**: Add to showroom
   - ⏸️ **Wait**: Hold for review
   - ❌ **Drop**: Do not stock
4. Items automatically queue for manager approval

### For Managers

1. **Home** → **Warehouse Mode** → **Manager**
2. **Swipe right** to approve ✅
3. **Swipe left** to reject ❌
4. View complete product details on each card
5. Approved items move to placement queue

### For Placement Staff

1. **Home** → **Warehouse Mode** → **Placement**
2. **View approved items**
3. **Assign shelf location** (e.g., "A-12-3")
4. Items appear in showroom inventory

### Uploading Catalogs

1. **Home** → **Upload Files**
2. **Select Excel file** (XLSX or XLSB)
3. **Choose category:**
   - Key Initiative
   - All Bought
4. **Upload** and wait for parsing
5. Data syncs to all devices automatically

---

## 🔌 API Documentation

### Base URL
```
Development: http://localhost:8000
Production:  https://your-app.railway.app
```

### Authentication
Currently, the API uses device_id for tracking. Future versions will implement JWT authentication.

### Key Endpoints

#### Health Check
```http
GET /health
```
Response:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

#### Upload File
```http
POST /api/files/upload
Content-Type: multipart/form-data

Fields:
- file: Excel/PDF file
- file_type: "xlsx" or "pdf"
- category: "key_initiative" or "all_bought"
```

#### Lookup Style
```http
GET /api/lookup?style=144083&color=Black
```

#### Create Classification
```http
POST /api/warehouse/classify
Content-Type: application/json

{
  "style_number": "144083",
  "color": "Black",
  "status": "keep",
  "coordinator_name": "John Doe",
  "confidence_score": 0.95
}
```

#### Get Pending Approvals
```http
GET /api/warehouse/pending?limit=50
```

#### Approve Classification
```http
POST /api/warehouse/approve
Content-Type: application/json

{
  "classification_id": 123,
  "approved": true,
  "manager_user_id": 5
}
```

#### Full Sync
```http
GET /api/sync/?device_id=ABC123
```

#### Incremental Sync
```http
GET /api/sync/changes?since=2024-01-15T10:00:00Z&device_id=ABC123
```

#### System Statistics
```http
GET /api/admin/stats
```

---

## 🐛 Troubleshooting

### Backend Issues

**Problem: "Tesseract not found"**
```bash
# macOS
brew install tesseract

# Ubuntu
sudo apt-get install tesseract-ocr

# Set path in .env
TESSERACT_PATH=/usr/local/bin/tesseract
```

**Problem: "Database connection failed"**
- Check DATABASE_URL in .env
- Verify PostgreSQL is running: `pg_isready`
- Test connection: `psql $DATABASE_URL`

**Problem: "Module not found"**
```bash
pip install -r requirements.txt
# or
pip install package-name
```

### iOS Issues

**Problem: "Connection failed"**
- Verify backend is running
- Check backend URL in Settings
- Ensure device and Mac are on same network
- Test connection in Settings tab

**Problem: "Camera permission denied"**
- Go to Settings app → Skechers Inventory → Camera → Enable

**Problem: "Sync not working"**
- Check network connection
- Verify backend URL
- Check for pending changes count on Home screen
- Try manual sync in Settings

**Problem: "Build failed in Xcode"**
- Clean build folder: Shift+⌘+K
- Reset package caches: File → Packages → Reset Package Caches
- Update Xcode to latest version

---

## 🏗️ Project Structure

```
SkechersInventorySystem/
├── backend/
│   ├── app/
│   │   ├── core/           # Config, database
│   │   ├── models/         # SQLAlchemy & Pydantic models
│   │   ├── routes/         # API endpoints (NOT USED - integrated into fastapi_server.py)
│   │   └── services/       # Business logic
│   ├── uploads/            # File storage
│   ├── fastapi_server.py   # Main server (ALL ROUTES HERE)
│   ├── requirements.txt
│   └── .env.example
│
├── ios/SkechersInventory/
│   ├── Managers/           # APIManager, DatabaseManager, SyncManager
│   ├── Views/              # SwiftUI screens (15+ views)
│   ├── Models/             # Data models
│   ├── Components/         # Reusable UI components
│   └── Utilities/          # Helper functions
│
└── README.md
```

---

## 🔐 Security Notes

- ⚠️ **Development mode** has CORS enabled for all origins
- ⚠️ Add authentication before production deployment
- ⚠️ Use HTTPS in production
- ⚠️ Rotate SECRET_KEY regularly
- ⚠️ Validate file uploads (size, type)
- ⚠️ Sanitize user inputs

---

## 📄 License

Proprietary - Skechers Corporation

---

## 👥 Support

For issues, questions, or feature requests:
- Create an issue on GitHub
- Contact: your-email@skechers.com

---

## 🎯 Next Steps

### Recommended Improvements
1. ✅ Add user authentication (JWT)
2. ✅ Implement role-based permissions
3. ✅ Add comprehensive test suite
4. ✅ Set up CI/CD pipeline
5. ✅ Add performance monitoring
6. ✅ Implement data export (CSV/Excel)
7. ✅ Add bulk operations
8. ✅ Create web dashboard

---

**Built with ❤️ for Skechers Inventory Management**
