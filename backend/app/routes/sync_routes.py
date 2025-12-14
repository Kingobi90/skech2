from flask import Blueprint, request, jsonify
import logging
from datetime import datetime
from app.core.database import SessionLocal
from app.models.database_models import File, Style, Color, ShowroomPlacement, SyncLog
import json

logger = logging.getLogger(__name__)

sync_bp = Blueprint('sync', __name__, url_prefix='/api/sync')

@sync_bp.route('/', methods=['GET'])
def full_sync():
    """Get complete data snapshot for offline sync."""
    try:
        db = SessionLocal()
        try:
            # Get all active files
            files = db.query(File).filter(File.is_active == True).all()
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
            device_id = request.args.get('device_id', 'unknown')
            sync_log = SyncLog(
                device_id=device_id,
                sync_status='success',
                sync_type='full',
                records_synced=len(styles_data) + len(placements_data)
            )
            db.add(sync_log)
            db.commit()
            
            return jsonify({
                'files': files_data,
                'styles': styles_data,
                'placements': placements_data,
                'sync_metadata': {
                    'current_timestamp': datetime.utcnow().isoformat(),
                    'total_styles': len(styles_data),
                    'total_placements': len(placements_data)
                }
            }), 200
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error in full sync: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500


@sync_bp.route('/changes', methods=['GET'])
def incremental_sync():
    """Get incremental changes since last sync."""
    try:
        since = request.args.get('since')
        if not since:
            return jsonify({'error': 'since parameter is required'}), 400
        
        since_datetime = datetime.fromisoformat(since.replace('Z', '+00:00'))
        
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
            device_id = request.args.get('device_id', 'unknown')
            sync_log = SyncLog(
                device_id=device_id,
                sync_status='success',
                sync_type='incremental',
                records_synced=len(styles_data) + len(placements_data)
            )
            db.add(sync_log)
            db.commit()
            
            return jsonify({
                'styles': styles_data,
                'placements': placements_data,
                'sync_metadata': {
                    'current_timestamp': datetime.utcnow().isoformat(),
                    'changes_count': len(styles_data) + len(placements_data)
                }
            }), 200
        
        finally:
            db.close()
    
    except Exception as e:
        logger.exception(f"Error in incremental sync: {str(e)}")
        return jsonify({'error': 'Internal server error'}), 500
