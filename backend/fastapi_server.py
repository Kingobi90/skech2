#!/usr/bin/env python3
"""
Skechers Inventory FastAPI Server
Enhanced with OCR, WebSocket, and activity logging
"""

import time
import logging
import tempfile
import os
from pathlib import Path
from typing import Dict, Any, List, Optional
from fastapi import FastAPI, Query, File, Form, UploadFile, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pynput.keyboard import Controller, Key
import pyautogui
import pytesseract
from PIL import Image
import io

from app.services.excel_parser_enhanced import (
    parse_excel_ki,
    parse_excel_allbought,
    parse_xlsb_file
)
from app.core.database import SessionLocal, init_db
from app.services.database_service import save_excel_data, log_audit_action
from app.models.database_models import File as FileModel
from app.core.config import settings

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize database tables
try:
    init_db()
    logger.info("✅ Database initialized successfully")
except Exception as e:
    logger.error(f"❌ Database initialization failed: {e}")

app = FastAPI(title="Skechers Inventory Server")

# Configure pytesseract if path is set
if settings.TESSERACT_PATH:
    pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_PATH
    logger.info(f"✅ Tesseract configured at: {settings.TESSERACT_PATH}")
else:
    logger.warning("⚠️  TESSERACT_PATH not set - using system PATH")

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.device_info: Dict[WebSocket, Dict[str, str]] = {}
    
    async def connect(self, websocket: WebSocket, device_id: str, user_name: str):
        await websocket.accept()
        self.active_connections.append(websocket)
        self.device_info[websocket] = {"device_id": device_id, "user_name": user_name}
        logger.info(f"📱 Device connected: {user_name} ({device_id})")
    
    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)
            info = self.device_info.pop(websocket, {})
            logger.info(f"📱 Device disconnected: {info.get('user_name', 'Unknown')}")
    
    async def broadcast(self, message: dict, exclude: WebSocket = None):
        """Broadcast message to all connected devices except sender"""
        disconnected = []
        for connection in self.active_connections:
            if connection != exclude:
                try:
                    await connection.send_json(message)
                except Exception as e:
                    logger.error(f"Error broadcasting to device: {e}")
                    disconnected.append(connection)
        
        for conn in disconnected:
            self.disconnect(conn)
    
    def get_connected_devices(self) -> List[Dict[str, str]]:
        return [info for info in self.device_info.values()]

manager = ConnectionManager()
activity_log: List[Dict[str, Any]] = []

IMAGES_DIR = Path("./uploads/shoe_images")
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

logger.info(f"📁 Images will be saved to: {IMAGES_DIR.absolute()}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

try:
    app.mount("/uploads/shoe_images", StaticFiles(directory=str(IMAGES_DIR)), name="shoe_images")
    logger.info("✅ Static image serving enabled at /uploads/shoe_images")
except Exception as e:
    logger.warning(f"⚠️  Could not mount static files: {e}")

# Keyboard controller for OCR
keyboard = Controller()

# OCR screenshot region (configurable)
SCREENSHOT_REGION = {
    "left": 400,
    "top": 50,
    "width": 800,
    "height": 200
}

def type_code(code: str) -> Dict[str, Any]:
    """Type code into focused field using system keyboard"""
    try:
        logger.info(f"🎹 Typing code: {code}")
        time.sleep(0.1)
        
        for char in code:
            keyboard.type(char)
            time.sleep(0.05)
        
        logger.info(f"✅ Typed {len(code)} characters")
        return {
            "success": True,
            "typed_chars": len(code),
            "message": f"Typed {code}"
        }
    except Exception as e:
        logger.error(f"❌ Typing error: {e}")
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to type code"
        }

def press_tab() -> Dict[str, Any]:
    """Press Tab key to move to next field"""
    try:
        logger.info("⇥ Pressing Tab key")
        keyboard.press(Key.tab)
        time.sleep(0.05)
        keyboard.release(Key.tab)
        logger.info("✅ Tab pressed")
        return {"success": True, "message": "Tab pressed"}
    except Exception as e:
        logger.error(f"❌ Tab press error: {e}")
        return {"success": False, "error": str(e), "message": "Failed to press Tab"}

def capture_and_ocr() -> Dict[str, Any]:
    """Capture screenshot and read text with OCR"""
    try:
        logger.info("📸 Capturing screenshot for OCR")
        
        screenshot = pyautogui.screenshot(region=(
            SCREENSHOT_REGION["left"],
            SCREENSHOT_REGION["top"],
            SCREENSHOT_REGION["width"],
            SCREENSHOT_REGION["height"]
        ))
        
        img_byte_arr = io.BytesIO()
        screenshot.save(img_byte_arr, format='PNG')
        img_byte_arr.seek(0)
        image = Image.open(img_byte_arr)
        
        ocr_text = pytesseract.image_to_string(image)
        logger.info(f"📝 OCR detected text: {ocr_text[:100]}...")
        
        ocr_lower = ocr_text.lower()
        
        if "no style found" in ocr_lower or "not found" in ocr_lower:
            return {
                "success": True,
                "style_found": False,
                "ocr_text": ocr_text.strip(),
                "message": "Style not found on website"
            }
        elif "please enter" in ocr_lower or "please complete" in ocr_lower:
            return {
                "success": True,
                "style_found": False,
                "ocr_text": ocr_text.strip(),
                "message": "Style validation failed"
            }
        else:
            return {
                "success": True,
                "style_found": True,
                "ocr_text": ocr_text.strip(),
                "message": "Style appears to be valid"
            }
    except Exception as e:
        logger.error(f"❌ OCR error: {e}")
        return {
            "success": False,
            "error": str(e),
            "message": "Failed to capture/read screenshot"
        }


@app.get("/")
@app.get("/health")
async def root():
    """Health check endpoint"""
    return {
        "status": "online",
        "service": "Skechers Inventory Server",
        "version": "1.0.0",
        "features": [
            "excel_parsing",
            "image_extraction",
            "xlsb_support",
            "ocr_validation",
            "keyboard_typing",
            "websocket_sync",
            "activity_logging"
        ],
        "connected_devices": len(manager.active_connections)
    }


@app.get("/api/health")
async def api_health():
    """API health check"""
    try:
        from app.core.database import SessionLocal
        db = SessionLocal()
        db.execute('SELECT 1')
        db.close()
        database_status = 'healthy'
    except Exception as e:
        logger.error(f"Database health check failed: {str(e)}")
        database_status = 'unhealthy'
    
    return {
        'status': 'healthy' if database_status == 'healthy' else 'degraded',
        'database_status': database_status
    }


@app.post("/api/files/upload")
async def upload_file(
    file: UploadFile = File(...),
    file_type: Optional[str] = Form(None),
    category: Optional[str] = Form(None)
):
    """Upload and parse Excel file - compatible with existing iOS app endpoint"""
    logger.info(f"📥 Received file: {file.filename}, type: {file_type}, category: {category}")

    try:
        # Determine file type and category
        filename_lower = file.filename.lower()
        is_xlsb = filename_lower.endswith('.xlsb')
        is_xlsx = filename_lower.endswith('.xlsx') or filename_lower.endswith('.xls')

        if not (is_xlsb or is_xlsx):
            return JSONResponse(
                status_code=400,
                content={'error': 'Invalid file type. Only XLSX and XLSB files are supported.'}
            )

        # Use provided category or detect from filename
        if not category:
            if 'ki' in filename_lower or 'key' in filename_lower:
                category = 'key_initiative'
            elif 'bought' in filename_lower or 'all' in filename_lower:
                category = 'all_bought'
            else:
                category = 'all_bought'  # Default to all_bought

        # Use provided file_type or set based on extension
        if not file_type:
            file_type = 'xlsb' if is_xlsb else 'xlsx'
        
        suffix = '.xlsb' if is_xlsb else '.xlsx'
        
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            content = await file.read()
            tmp.write(content)
            tmp_path = Path(tmp.name)
        
        # Parse based on file type
        if is_xlsb:
            logger.info("📊 Parsing as XLSB (binary Excel)")
            items = parse_xlsb_file(tmp_path)
        elif category == 'all_bought':
            logger.info("📊 Parsing as All Bought XLSX")
            items = parse_excel_allbought(tmp_path)
        else:
            logger.info("📊 Parsing as KI XLSX with image extraction")
            items = parse_excel_ki(tmp_path)
        
        tmp_path.unlink()
        
        db = SessionLocal()
        try:
            file_record = FileModel(
                filename=file.filename,
                original_filename=file.filename,
                file_type=file_type,
                category=category,
                status='processing'
            )
            db.add(file_record)
            db.commit()
            db.refresh(file_record)
            file_id = file_record.id
            
            # Convert items to format expected by save_excel_data
            extracted_data = []
            for item in items:
                style_data = {
                    'style_number': item['style'],
                    'division': item.get('division'),
                    'gender': None,
                    'outsole': item.get('outsole'),
                    'colors': [{
                        'color_name': item['color'],
                        'image_url': item.get('image')
                    }],
                    'width_variants': []
                }
                extracted_data.append(style_data)
            
            save_stats = save_excel_data(db, file_id, extracted_data)
            
            from datetime import datetime
            file_record.parsed_at = datetime.utcnow()
            file_record.row_count = len(items)
            file_record.status = 'success'
            db.commit()
            
            log_audit_action(
                db,
                'file_uploaded',
                affected_resources=f"File ID: {file_id}",
                ip_address="127.0.0.1",
                details=f"File uploaded: {file.filename}"
            )
            
            logger.info(f"✅ Saved {len(items)} items to database")

            # Return response in format expected by iOS app
            return JSONResponse(content={
                "file_id": file_id,
                "filename": file.filename,
                "file_type": file_type,
                "category": category,
                "parsing_summary": {
                    "total_rows_processed": len(items),
                    "total_styles_found": save_stats.get('styles_created', 0) + save_stats.get('styles_updated', 0),
                    "total_colors_found": save_stats.get('colors_created', 0),
                    "styles_created": save_stats.get('styles_created', 0),
                    "styles_updated": save_stats.get('styles_updated', 0),
                    "colors_created": save_stats.get('colors_created', 0)
                },
                "warnings": [],
                "extracted_data": extracted_data
            })
            
        finally:
            db.close()
    
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        logger.error(f"❌ Parse error: {e}")
        logger.error(f"Full traceback:\n{error_details}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/files/{file_id}")
async def delete_file(file_id: int):
    """Delete a file and all associated data"""
    logger.info(f"🗑️ Delete request for file ID: {file_id}")

    db = SessionLocal()
    try:
        # Get the file record
        file_record = db.query(FileModel).filter(FileModel.id == file_id).first()
        if not file_record:
            raise HTTPException(status_code=404, detail="File not found")

        # Delete associated styles and colors
        styles_deleted = db.execute(
            text("DELETE FROM styles WHERE source_file_ids LIKE :pattern"),
            {"pattern": f"%{file_id}%"}
        ).rowcount

        # Colors are deleted via cascade

        # Delete the file record
        db.delete(file_record)
        db.commit()

        logger.info(f"✅ Deleted file {file_id} and {styles_deleted} associated styles")

        return {
            "success": True,
            "file_id": file_id,
            "styles_deleted": styles_deleted,
            "message": "File and associated data deleted successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"❌ Delete error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        db.close()


@app.get("/api/lookup")
async def lookup_with_ocr(code: str = Query(..., description="Style code to type and validate")):
    """Type code, press Tab, and validate with OCR"""
    start_time = time.time()
    
    logger.info(f"📱 Received lookup request for code: {code}")
    
    # Step 1: Type the code
    type_result = type_code(code)
    if not type_result["success"]:
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": type_result.get("error"),
                "message": "Failed to type code"
            }
        )
    
    # Step 2: Press Tab
    tab_result = press_tab()
    if not tab_result["success"]:
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "error": tab_result.get("error"),
                "message": "Failed to press Tab"
            }
        )
    
    # Step 3: Wait for validation
    logger.info("⏳ Waiting for page validation...")
    time.sleep(1.5)
    
    # Step 4: OCR validation
    ocr_result = capture_and_ocr()
    
    elapsed_time = time.time() - start_time
    
    response = {
        "success": True,
        "code": code,
        "typed_chars": type_result.get("typed_chars", 0),
        "pressed_tab": True,
        "style_found": ocr_result.get("style_found", False),
        "ocr_text": ocr_result.get("ocr_text", ""),
        "message": ocr_result.get("message", "Completed"),
        "elapsed_time": round(elapsed_time, 2)
    }
    
    logger.info(f"✅ Lookup completed in {elapsed_time:.2f}s - Style found: {response['style_found']}")
    
    # Broadcast to connected devices
    await manager.broadcast({
        "type": "lookup_completed",
        "data": {
            "code": code,
            "style_found": response['style_found']
        }
    })
    
    return JSONResponse(content=response)


@app.get("/api/cv/detect")
async def cv_detect_fallback():
    """Fallback for CV detection - use OCR instead"""
    return JSONResponse(
        status_code=501,
        content={
            "success": False,
            "message": "CV detection not implemented. Use /api/lookup for OCR validation."
        }
    )


@app.post("/api/activity/log")
async def log_activity(activity: dict):
    """Log user activity and broadcast to connected devices"""
    activity_log.append({
        **activity,
        "timestamp": time.time()
    })
    
    # Broadcast to all connected devices
    await manager.broadcast({
        "type": "activity",
        "data": activity
    })
    
    logger.info(f"📝 Activity logged: {activity.get('action')} by {activity.get('user', 'Unknown')}")
    
    return {"success": True, "message": "Activity logged"}


@app.get("/api/activity/recent")
async def get_recent_activity(limit: int = Query(50, description="Number of recent activities to return")):
    """Get recent activity log entries"""
    return {
        "success": True,
        "activities": activity_log[-limit:],
        "count": len(activity_log[-limit:])
    }


@app.websocket("/ws/{device_id}/{user_name}")
async def websocket_endpoint(websocket: WebSocket, device_id: str, user_name: str):
    """WebSocket endpoint for real-time multi-device sync"""
    await manager.connect(websocket, device_id, user_name)
    
    try:
        while True:
            data = await websocket.receive_json()
            
            # Handle different message types
            if data.get("type") == "session_summary":
                # Broadcast session summary to all other devices
                await manager.broadcast({
                    "type": "notification",
                    "title": f"{user_name}'s session ended",
                    "body": data.get("summary", "")
                }, exclude=websocket)
            
            elif data.get("type") == "inventory_update":
                # Broadcast inventory update
                await manager.broadcast({
                    "type": "notification",
                    "title": "Inventory Updated",
                    "body": f"{user_name} updated inventory"
                }, exclude=websocket)
            
            elif data.get("type") == "file_uploaded":
                # Broadcast file upload notification
                await manager.broadcast({
                    "type": "notification",
                    "title": "File Uploaded",
                    "body": f"{user_name} uploaded {data.get('filename', 'a file')}"
                }, exclude=websocket)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)


@app.get("/api/devices/connected")
async def get_connected_devices():
    """Get list of currently connected devices"""
    return {
        "success": True,
        "devices": manager.get_connected_devices(),
        "count": len(manager.active_connections)
    }


# ============================================================================
# WAREHOUSE ROUTES (from warehouse_routes.py)
# ============================================================================

from app.models.database_models import WarehouseClassification, ShowroomPlacement
from app.services.database_service import (
    get_pending_classifications, approve_classification, create_placement
)
from datetime import datetime

@app.post("/api/warehouse/classify")
async def classify_item(data: dict):
    """Create a new warehouse classification."""
    if not data.get('style_number') or not data.get('color') or not data.get('status'):
        raise HTTPException(status_code=400, detail='style_number, color, and status are required')

    if data['status'] not in ['keep', 'wait', 'drop']:
        raise HTTPException(status_code=400, detail='status must be keep, wait, or drop')

    db = SessionLocal()
    try:
        classification = WarehouseClassification(
            style_number=data['style_number'],
            color=data['color'],
            status=data['status'],
            coordinator_user_id=data.get('coordinator_user_id'),
            coordinator_name=data.get('coordinator_name'),
            confidence_score=data.get('confidence_score'),
            notes=data.get('notes')
        )

        db.add(classification)
        db.commit()
        db.refresh(classification)

        return JSONResponse(content={
            'classification_id': classification.id,
            'style_number': classification.style_number,
            'color': classification.color,
            'status': classification.status,
            'message': 'Classification created successfully'
        }, status_code=201)

    except Exception as e:
        logger.exception(f"Error creating classification: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.get("/api/warehouse/pending")
async def get_pending(limit: int = Query(100, description="Number of items to return")):
    """Get pending classifications for manager approval."""
    db = SessionLocal()
    try:
        pending = get_pending_classifications(db, limit)
        return JSONResponse(content={'pending_classifications': pending})
    except Exception as e:
        logger.exception(f"Error getting pending classifications: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.post("/api/warehouse/approve")
async def approve(data: dict):
    """Approve or reject a classification."""
    if not data.get('classification_id') or 'approved' not in data:
        raise HTTPException(status_code=400, detail='classification_id and approved are required')

    db = SessionLocal()
    try:
        result = approve_classification(
            db,
            data['classification_id'],
            data['approved'],
            data.get('manager_user_id'),
            data.get('notes')
        )

        return JSONResponse(content={
            'message': 'Classification approved successfully',
            **result
        })

    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.exception(f"Error approving classification: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.post("/api/warehouse/placement")
async def create_placement_route(data: dict):
    """Create a showroom placement for an approved item."""
    if not data.get('classification_id') or not data.get('shelf_location'):
        raise HTTPException(status_code=400, detail='classification_id and shelf_location are required')

    db = SessionLocal()
    try:
        result = create_placement(
            db,
            data['classification_id'],
            data['shelf_location'],
            data.get('coordinator_user_id')
        )

        return JSONResponse(content={
            'message': 'Placement created successfully',
            **result
        }, status_code=201)

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception(f"Error creating placement: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.get("/api/warehouse/placements")
async def get_placements(
    style_number: Optional[str] = Query(None),
    shelf_location: Optional[str] = Query(None),
    page: int = Query(1),
    limit: int = Query(50)
):
    """Get all showroom placements with optional filters."""
    db = SessionLocal()
    try:
        query = db.query(ShowroomPlacement).filter(ShowroomPlacement.is_active == True)

        if style_number:
            query = query.filter(ShowroomPlacement.style_number.ilike(f"%{style_number}%"))

        if shelf_location:
            query = query.filter(ShowroomPlacement.shelf_location == shelf_location)

        total_count = query.count()

        offset = (page - 1) * limit
        placements = query.order_by(ShowroomPlacement.placement_timestamp.desc()).offset(offset).limit(limit).all()

        return JSONResponse(content={
            'placements': [{
                'id': p.id,
                'style_number': p.style_number,
                'color': p.color,
                'shelf_location': p.shelf_location,
                'placement_timestamp': p.placement_timestamp.isoformat()
            } for p in placements],
            'total_count': total_count,
            'page': page,
            'limit': limit
        })

    except Exception as e:
        logger.exception(f"Error getting placements: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


# ============================================================================
# SYNC ROUTES (from sync_routes.py)
# ============================================================================

from app.models.database_models import Style, Color, SyncLog
import json

@app.get("/api/sync/")
async def full_sync(device_id: str = Query("unknown")):
    """Get complete data snapshot for offline sync."""
    db = SessionLocal()
    try:
        # Get all active files
        files = db.query(FileModel).filter(FileModel.is_active == True).all()
        files_data = [{
            'id': f.id,
            'filename': f.original_filename,
            'file_type': f.file_type,
            'category': f.category,
            'upload_date': f.upload_date.isoformat()
        } for f in files]

        # Get all styles with colors
        styles = db.query(Style).all()
        styles_data = []
        for style in styles:
            colors = db.query(Color).filter(Color.style_id == style.id).all()
            styles_data.append({
                'id': style.id,
                'style_number': style.style_number,
                'division': style.division,
                'gender': style.gender,
                'outsole': style.outsole,
                'source_file_ids': json.loads(style.source_file_ids or '[]'),
                'colors': [c.color_name for c in colors],
                'updated_at': style.updated_at.isoformat() if style.updated_at else style.created_at.isoformat()
            })

        # Get all active placements
        placements = db.query(ShowroomPlacement).filter(ShowroomPlacement.is_active == True).all()
        placements_data = [{
            'id': p.id,
            'style_number': p.style_number,
            'color': p.color,
            'shelf_location': p.shelf_location,
            'placement_timestamp': p.placement_timestamp.isoformat()
        } for p in placements]

        # Record sync
        sync_log = SyncLog(
            device_id=device_id,
            sync_status='success',
            sync_type='full',
            records_synced=len(styles_data) + len(placements_data)
        )
        db.add(sync_log)
        db.commit()

        return JSONResponse(content={
            'files': files_data,
            'styles': styles_data,
            'placements': placements_data,
            'sync_metadata': {
                'current_timestamp': datetime.utcnow().isoformat(),
                'total_styles': len(styles_data),
                'total_placements': len(placements_data)
            }
        })

    except Exception as e:
        logger.exception(f"Error in full sync: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.get("/api/sync/changes")
async def incremental_sync(
    since: str = Query(..., description="ISO timestamp of last sync"),
    device_id: str = Query("unknown")
):
    """Get incremental changes since last sync."""
    try:
        since_datetime = datetime.fromisoformat(since.replace('Z', '+00:00'))
    except ValueError:
        raise HTTPException(status_code=400, detail='Invalid since parameter format')

    db = SessionLocal()
    try:
        # Get styles updated since timestamp
        updated_styles = db.query(Style).filter(
            Style.updated_at > since_datetime
        ).all()

        styles_data = []
        for style in updated_styles:
            colors = db.query(Color).filter(Color.style_id == style.id).all()
            styles_data.append({
                'id': style.id,
                'style_number': style.style_number,
                'division': style.division,
                'gender': style.gender,
                'outsole': style.outsole,
                'colors': [c.color_name for c in colors],
                'updated_at': style.updated_at.isoformat() if style.updated_at else style.created_at.isoformat(),
                'change_type': 'updated'
            })

        # Get recent placements
        recent_placements = db.query(ShowroomPlacement).filter(
            ShowroomPlacement.placement_timestamp > since_datetime
        ).all()

        placements_data = [{
            'id': p.id,
            'style_number': p.style_number,
            'color': p.color,
            'shelf_location': p.shelf_location,
            'placement_timestamp': p.placement_timestamp.isoformat(),
            'change_type': 'created'
        } for p in recent_placements]

        # Record sync
        sync_log = SyncLog(
            device_id=device_id,
            sync_status='success',
            sync_type='incremental',
            records_synced=len(styles_data) + len(placements_data)
        )
        db.add(sync_log)
        db.commit()

        return JSONResponse(content={
            'styles': styles_data,
            'placements': placements_data,
            'sync_metadata': {
                'current_timestamp': datetime.utcnow().isoformat(),
                'changes_count': len(styles_data) + len(placements_data)
            }
        })

    except Exception as e:
        logger.exception(f"Error in incremental sync: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


# ============================================================================
# LOOKUP ROUTES (from lookup_routes.py)
# ============================================================================

from app.services.database_service import lookup_style_color
from sqlalchemy import func, or_, text

@app.get("/api/lookup/")
async def lookup(style: str = Query(...), color: Optional[str] = Query(None)):
    """Lookup style and color in database."""
    db = SessionLocal()
    try:
        result = lookup_style_color(db, style, color)
        return JSONResponse(content=result)
    except Exception as e:
        logger.exception(f"Error in lookup: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.get("/api/lookup/search")
async def search(
    q: str = Query(""),
    status_filter: Optional[str] = Query(None, alias="status"),
    division_filter: Optional[str] = Query(None, alias="division"),
    gender_filter: Optional[str] = Query(None, alias="gender"),
    page: int = Query(1),
    limit: int = Query(50)
):
    """Search styles by query string."""
    if not q and not status_filter and not division_filter and not gender_filter:
        raise HTTPException(status_code=400, detail='At least one search parameter required')

    db = SessionLocal()
    try:
        # Build query
        styles_query = db.query(Style)

        if q:
            # Search in style number, division
            search_pattern = f"%{q}%"
            styles_query = styles_query.filter(
                or_(
                    Style.style_number.ilike(search_pattern),
                    Style.division.ilike(search_pattern)
                )
            )

        if division_filter:
            styles_query = styles_query.filter(Style.division == division_filter)

        if gender_filter:
            styles_query = styles_query.filter(Style.gender == gender_filter)

        # Get total count
        total_count = styles_query.count()

        # Paginate
        offset = (page - 1) * limit
        styles = styles_query.offset(offset).limit(limit).all()

        # Format results
        results = []
        for style in styles:
            colors = db.query(Color).filter(Color.style_id == style.id).all()
            results.append({
                'style_number': style.style_number,
                'division': style.division,
                'gender': style.gender,
                'outsole': style.outsole,
                'colors': [c.color_name for c in colors]
            })

        return JSONResponse(content={
            'results': results,
            'total_count': total_count,
            'page': page,
            'limit': limit,
            'total_pages': (total_count + limit - 1) // limit
        })

    except Exception as e:
        logger.exception(f"Error in search: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


# ============================================================================
# ADMIN ROUTES (from admin_routes.py)
# ============================================================================

from app.services.database_service import get_statistics
from app.models.database_models import RemovalTask

@app.get("/api/admin/stats")
async def get_stats():
    """Get system statistics for dashboard."""
    db = SessionLocal()
    try:
        stats = get_statistics(db)
        return JSONResponse(content=stats)
    except Exception as e:
        logger.exception(f"Error getting statistics: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.get("/api/admin/removal-tasks")
async def get_removal_tasks():
    """Get pending removal tasks."""
    db = SessionLocal()
    try:
        tasks = db.query(RemovalTask).filter(
            RemovalTask.completed == False
        ).order_by(RemovalTask.created_timestamp.desc()).all()

        return JSONResponse(content={
            'removal_tasks': [{
                'task_id': t.id,
                'style_number': t.style_number,
                'color': t.color,
                'shelf_location': t.shelf_location,
                'reason': t.reason,
                'created_timestamp': t.created_timestamp.isoformat()
            } for t in tasks]
        })

    except Exception as e:
        logger.exception(f"Error getting removal tasks: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.put("/api/admin/removal-tasks/{task_id}/complete")
async def complete_removal_task(task_id: int):
    """Mark a removal task as completed."""
    db = SessionLocal()
    try:
        task = db.query(RemovalTask).filter(RemovalTask.id == task_id).first()

        if not task:
            raise HTTPException(status_code=404, detail='Task not found')

        task.completed = True
        task.completed_timestamp = datetime.utcnow()
        db.commit()

        log_audit_action(
            db,
            'removal_task_completed',
            affected_resources=f"Task ID: {task_id}",
            ip_address="127.0.0.1",
            details=f"Removal task completed: {task.style_number} - {task.color}"
        )

        return JSONResponse(content={
            'message': 'Removal task marked as completed',
            'task_id': task_id
        })

    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Error completing removal task: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.get("/api/admin/config")
async def get_system_config():
    """Get system configuration."""
    return JSONResponse(content={
        'auto_drop_enabled': settings.AUTO_DROP_ENABLED,
        'default_sync_interval_seconds': settings.DEFAULT_SYNC_INTERVAL_SECONDS,
        'max_content_length': settings.MAX_CONTENT_LENGTH
    })


@app.put("/api/admin/config")
async def update_system_config(data: dict):
    """Update system configuration."""
    # Note: In production, you'd want to persist these changes
    # For now, this just returns the requested config
    return JSONResponse(content={
        'message': 'Configuration updated',
        'config': data
    })


# ============================================================================
# CV ROUTES (from cv_routes.py)
# ============================================================================

from app.services.cv_processor import process_shoe_tag_image

@app.post("/api/cv/detect")
async def detect_tag(data: dict):
    """Process shoe tag image and detect style number and color."""
    if not data or 'image_data' not in data:
        raise HTTPException(status_code=400, detail='image_data is required')

    try:
        # Process image
        result = process_shoe_tag_image(data['image_data'])
        return JSONResponse(content=result)

    except Exception as e:
        logger.exception(f"Error in CV detection: {str(e)}")
        return JSONResponse(content={
            'success': False,
            'message': 'Internal server error',
            'detected_style_number': None,
            'detected_color': None,
            'confidence_score': 0.0
        }, status_code=500)


# ============================================================================
# FILES ROUTES (additional endpoints not in main upload)
# ============================================================================

@app.get("/api/files/")
async def list_files():
    """List all uploaded files."""
    db = SessionLocal()
    try:
        files = db.query(FileModel).filter(FileModel.is_active == True).order_by(FileModel.upload_date.desc()).all()

        return JSONResponse(content={
            'files': [{
                'id': f.id,
                'filename': f.original_filename,
                'file_type': f.file_type,
                'category': f.category,
                'upload_date': f.upload_date.isoformat(),
                'status': f.status,
                'row_count': f.row_count
            } for f in files]
        })
    except Exception as e:
        logger.exception(f"Error listing files: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


@app.delete("/api/files/{file_id}")
async def delete_file(file_id: int):
    """Delete a file and all associated data (styles, colors, images)."""
    db = SessionLocal()
    try:
        file_record = db.query(FileModel).filter(FileModel.id == file_id).first()

        if not file_record:
            raise HTTPException(status_code=404, detail='File not found')

        logger.info(f"🗑️ Deleting file: {file_record.original_filename} (ID: {file_id})")
        
        # Find all styles that ONLY reference this file
        styles_to_delete = []
        colors_deleted = 0
        images_deleted = 0
        
        all_styles = db.query(Style).all()
        for style in all_styles:
            source_file_ids = json.loads(style.source_file_ids or '[]')
            
            if file_id in source_file_ids:
                # Remove this file ID from the style's source files
                source_file_ids.remove(file_id)
                
                if len(source_file_ids) == 0:
                    # This style only exists in this file, delete it completely
                    styles_to_delete.append(style)
                    
                    # Get all colors for this style to delete their images
                    colors = db.query(Color).filter(Color.style_id == style.id).all()
                    for color in colors:
                        # Delete associated image file
                        if color.image_url:
                            image_path = Path(f".{color.image_url}")
                            if image_path.exists():
                                image_path.unlink()
                                images_deleted += 1
                                logger.info(f"   🖼️ Deleted image: {image_path}")
                    
                    colors_deleted += len(colors)
                else:
                    # Style exists in other files, just update the source_file_ids
                    style.source_file_ids = json.dumps(source_file_ids)
                    
                    # Delete colors that only reference this file
                    colors = db.query(Color).filter(
                        Color.style_id == style.id,
                        Color.source_file_id == file_id
                    ).all()
                    
                    for color in colors:
                        # Delete associated image file
                        if color.image_url:
                            image_path = Path(f".{color.image_url}")
                            if image_path.exists():
                                image_path.unlink()
                                images_deleted += 1
                                logger.info(f"   🖼️ Deleted image: {image_path}")
                        db.delete(color)
                        colors_deleted += 1
        
        # Delete the styles that only existed in this file
        for style in styles_to_delete:
            db.delete(style)
        
        # Delete the file record
        db.delete(file_record)
        db.commit()
        
        logger.info(f"✅ Deleted: {len(styles_to_delete)} styles, {colors_deleted} colors, {images_deleted} images")

        # Log audit action
        log_audit_action(
            db,
            'file_deleted',
            affected_resources=f"File ID: {file_id}",
            ip_address="127.0.0.1",
            details=f"File deleted: {file_record.original_filename}, Styles: {len(styles_to_delete)}, Colors: {colors_deleted}, Images: {images_deleted}"
        )

        return JSONResponse(content={
            'message': 'File and all associated data deleted successfully',
            'styles_deleted': len(styles_to_delete),
            'colors_deleted': colors_deleted,
            'images_deleted': images_deleted
        })

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.exception(f"Error deleting file: {str(e)}")
        raise HTTPException(status_code=500, detail='Internal server error')
    finally:
        db.close()


if __name__ == "__main__":
    import uvicorn
    import socket
    
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        local_ip = s.getsockname()[0]
    except Exception:
        local_ip = '127.0.0.1'
    finally:
        s.close()
    
    logger.info("🚀 Starting Skechers Inventory FastAPI Server")
    logger.info(f"📍 Server will run at: http://{local_ip}:8000")
    logger.info("📱 Configure this URL in iPhone app")
    logger.info("")
    logger.info("✅ Features enabled:")
    logger.info("   - Excel parsing (XLSX & XLSB)")
    logger.info("   - Image extraction from Excel")
    logger.info("   - Smart column detection")
    logger.info("   - OCR validation with keyboard typing")
    logger.info("   - WebSocket real-time sync")
    logger.info("   - Activity logging")
    logger.info("")
    logger.info("⚠️  For OCR: Grant accessibility permissions and place cursor in target field")
    logger.info("")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )
