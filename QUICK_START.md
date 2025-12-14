# Skechers Inventory System - Quick Start

## What's New

The system now has an **enhanced FastAPI server** that includes the working Excel parsing patterns from the old app:

✅ **Smart Excel Parsing** - Automatic column detection (no hardcoded positions)  
✅ **Image Extraction** - Extracts embedded images from Excel files  
✅ **XLSB Support** - Parse binary Excel files  
✅ **Compatible Endpoints** - Works with existing iOS app  

## Start the Server

```bash
cd backend
./start_server.sh
```

The server runs on **port 8000** and will display your local IP address.

## iOS App Configuration

The iOS app is already configured to use port 8000:

**File**: `ios/SkechersInventory/Managers/APIManager.swift`  
**Line 16**: `baseURL = "http://10.0.0.60:8000"`

Update the IP address to match your Mac's IP if needed.

## Key Features

### 1. Smart Column Detection

The parser automatically finds columns by analyzing data patterns:

- **Style**: Looks for 6-digit numbers
- **Color**: Looks for 3-4 letter codes (BBK, WSL, etc.)
- **Division, Outsole**: Detected by header names

**No hardcoded column positions needed!**

### 2. Image Extraction

When you upload an XLSX file with embedded images:

1. Images are extracted from cells
2. Saved as `{style}_{color}.png`
3. Accessible at `/uploads/shoe_images/{filename}`

### 3. XLSB Support

Binary Excel files (.xlsb) are parsed using `pyxlsb` for faster processing of large files.

## API Endpoint

### Upload File

```
POST /api/files/upload
```

**Supported formats**: XLSX, XLSB

**Auto-detection**: Category (KI/All Bought) detected from filename

**Response**:
```json
{
  "file_id": 1,
  "filename": "test.xlsx",
  "file_type": "xlsx",
  "category": "key_initiative",
  "parsing_summary": {
    "total_rows_processed": 150,
    "total_styles_found": 100,
    "total_colors_found": 200,
    "styles_created": 80,
    "styles_updated": 20,
    "colors_created": 200
  },
  "warnings": []
}
```

## Testing

```bash
# Test server
curl http://localhost:8000/

# Upload file
curl -X POST http://localhost:8000/api/files/upload \
  -F "file=@test.xlsx"
```

## Excel File Format

Your Excel files can have columns in **any order**. The system detects them automatically:

### Required Columns
- **Style**: 6-digit numbers (e.g., 123456)
- **Color**: 3-4 letter codes (e.g., BBK, WSL)

### Optional Columns
- **Division**: Product category
- **Outsole**: Sole type
- **Color Description**: Full color name
- **Image**: Embedded images (XLSX only)

### Example

| Style  | Color | Division | Image |
|--------|-------|----------|-------|
| 123456 | BBK   | MENS     | [img] |
| 234567 | WSL   | WOMENS   | [img] |

## Troubleshooting

### Port Already in Use
```bash
kill -9 $(lsof -ti:8000)
```

### Images Not Extracting
- Ensure file is XLSX (not XLSB)
- Images must be embedded (not linked)
- Check `backend/uploads/shoe_images/` directory exists

### iOS App Can't Connect
```bash
# Find your Mac's IP
ipconfig getifaddr en0

# Update APIManager.swift with correct IP
```

## What Was Removed

The following features from the old app were **not** included (as requested):

❌ Keyboard typing automation  
❌ OCR validation  
❌ WebSocket real-time sync  
❌ Activity logging endpoints  

## What's Included

✅ Excel parsing with smart column detection  
✅ Image extraction from Excel  
✅ XLSB file support  
✅ Database integration  
✅ Compatible with existing iOS app endpoints  

## Next Steps

1. Start the FastAPI server: `./start_server.sh`
2. Build and run iOS app in Xcode
3. Upload an Excel file
4. Verify images are extracted (if XLSX with embedded images)

That's it! The system is ready to use.
