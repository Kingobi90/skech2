# Skechers Showroom Inventory Management System - Backend

Python Flask backend server for the Skechers Inventory Management System with computer vision, Excel/PDF parsing, and RESTful API.

## Features

- **File Processing**: Parse Excel files (pandas/openpyxl) and PDF files (pdfplumber) to extract product data
- **Computer Vision**: OCR processing of shoe tag images using OpenCV and Tesseract
- **RESTful API**: Complete API for iOS app with lookup, warehouse workflow, and sync endpoints
- **PostgreSQL Database**: Robust data storage with SQLAlchemy ORM
- **Auto-Drop Logic**: Automatically flag items for removal when source files are deleted
- **Audit Logging**: Complete audit trail for all administrative actions

## Tech Stack

- **Framework**: Flask 3.0
- **Database**: PostgreSQL with SQLAlchemy 2.0
- **Data Processing**: pandas, openpyxl, pdfplumber
- **Computer Vision**: OpenCV, pytesseract
- **Deployment**: Gunicorn, Railway, Cloudflare

## Installation

1. Clone the repository
2. Create virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Install Tesseract OCR:
- **macOS**: `brew install tesseract`
- **Ubuntu**: `sudo apt-get install tesseract-ocr`
- **Windows**: Download from https://github.com/UB-Mannheim/tesseract/wiki

5. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

6. Initialize database:
```bash
python -c "from app.core.database import init_db; init_db()"
```

## Running Locally

```bash
python app.py
```

Server will start on http://localhost:5000

## API Endpoints

### File Management
- `POST /api/files/upload` - Upload Excel or PDF file
- `GET /api/files/` - List all files
- `DELETE /api/files/<id>` - Delete file and trigger auto-drop

### Lookup & Search
- `GET /api/lookup?style=12345&color=Navy` - Lookup style/color
- `GET /api/search?q=running` - Search styles

### Warehouse Workflow
- `POST /api/warehouse/classify` - Create classification
- `GET /api/warehouse/pending` - Get pending approvals
- `POST /api/warehouse/approve` - Approve/reject item
- `POST /api/warehouse/placement` - Create showroom placement
- `GET /api/warehouse/placements` - List placements

### Computer Vision
- `POST /api/cv/detect` - Process shoe tag image

### Data Sync
- `GET /api/sync/` - Full data sync
- `GET /api/sync/changes?since=<timestamp>` - Incremental sync

### Admin
- `GET /api/admin/stats` - System statistics
- `GET /api/admin/removal-tasks` - Pending removal tasks
- `PUT /api/admin/removal-tasks/<id>/complete` - Complete task
- `GET /api/admin/config` - Get system configuration

### Health Check
- `GET /health` - Health check endpoint

## Deployment to Railway

1. Push code to GitHub
2. Connect repository to Railway
3. Add PostgreSQL plugin
4. Set environment variables in Railway dashboard
5. Deploy!

Railway will automatically:
- Detect Python project
- Install dependencies from requirements.txt
- Run with Gunicorn using Procfile

## Cloudflare Configuration

1. Add CNAME record: `api.yourdomain.com` → Railway URL
2. Enable proxy (orange cloud)
3. Set SSL/TLS to Full (strict)
4. Add page rule to bypass cache for `/api/*`

## Database Schema

- **files**: Uploaded Excel/PDF files
- **styles**: Product style numbers with details
- **colors**: Colors associated with styles
- **warehouse_classifications**: Coordinator scans and classifications
- **showroom_placements**: Items placed in showroom with locations
- **removal_tasks**: Items flagged for removal
- **sync_log**: Sync history for iOS devices
- **audit_log**: Administrative action audit trail

## Development

Run tests:
```bash
pytest
```

Check code style:
```bash
flake8 app/
```

## Environment Variables

- `DATABASE_URL`: PostgreSQL connection string
- `SECRET_KEY`: Flask secret key
- `DEBUG`: Enable debug mode (False in production)
- `UPLOAD_FOLDER`: Directory for uploaded files
- `TESSERACT_PATH`: Path to Tesseract binary (optional)
- `AUTO_DROP_ENABLED`: Enable auto-drop feature (default: True)
- `MAX_CONTENT_LENGTH`: Max upload size in bytes (default: 50MB)

## License

Proprietary - Skechers Showroom Inventory Management System
